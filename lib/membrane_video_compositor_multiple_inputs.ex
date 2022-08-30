defmodule Membrane.VideoCompositor.MultipleInputs do
  @moduledoc """
  The element responsible for placing the first received frame
  above the other and sending forward buffer with
  merged frame binary in the payload.
  """

  use Membrane.Filter
  alias Membrane.RawVideo

  def_options implementation: [
                type: :atom,
                spec: :ffmpeg | :opengl | :nx,
                description: "Implementation of video composer."
              ],
              caps: [
                type: RawVideo,
                description: "Struct with video width, height, framerate and pixel format."
              ]

  def_input_pad(
    :input,
    demand_unit: :buffers,
    availability: :on_request,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}
  )

  def_output_pad(
    :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}
  )

  defmodule Track do
    @moduledoc false
    @type t :: %__MODULE__{
            buffers: Qex.t(Membrane.Buffer.t()),
            state: :playing | :end_of_stream
          }
    defstruct buffers: Qex.new(), state: :playing
  end

  @impl true
  def handle_init(options) do
    compositor_module = determine_compositor_module(options.implementation)

    {:ok, internal_state} = compositor_module.init(options.caps)

    state = %{
      ids_to_tracks: %{},
      caps: options.caps,
      compositor_module: compositor_module,
      internal_state: internal_state,
      pads_to_ids: {0, %{}}
    }

    {:ok, state}
  end

  @impl true
  def handle_pad_added(pad, _context, state) do
    state = add_video(pad, state)
    {:ok, state}
  end

  defp add_video(pad, state) do
    {new_id, pads_to_ids} = state.pads_to_ids
    state = %{state | pads_to_ids: {new_id + 1, Map.put(pads_to_ids, pad, new_id)}}

    %{state | ids_to_tracks: Map.put(state.ids_to_tracks, new_id, %Track{})}
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{pads_to_ids: {_new_id, pads_to_ids}, internal_state: internal_state} = state
    id = Map.get(pads_to_ids, pad)

    {:ok, internal_state} =
      state.compositor_module.add_video(id, caps, %{x: 0, y: 0}, internal_state)

    state = %{state | internal_state: internal_state}
    {{:ok, caps: {:output, state.caps}}, state}
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        %{
          ids_to_tracks: ids_to_tracks,
          internal_state: internal_state,
          pads_to_ids: {_new_id, pads_to_ids}
        } = state
      ) do
    id = Map.get(pads_to_ids, pad)

    ids_to_tracks = push_frame(ids_to_tracks, id, buffer)

    state = %{state | ids_to_tracks: ids_to_tracks}

    if all_has_frame?(ids_to_tracks) do
      ids_to_frames = get_ids_to_frames(ids_to_tracks)

      {{:ok, merged_frame_binary}, internal_state} =
        state.compositor_module.merge_frames(ids_to_frames, internal_state)

      ids_to_tracks = pop_frames(ids_to_tracks)

      state = %{
        state
        | ids_to_tracks: ids_to_tracks,
          internal_state: internal_state
      }

      state = remove_ended_videos(state)

      {{:ok, buffer: {:output, %Membrane.Buffer{payload: merged_frame_binary}}}, state}
    else
      {:ok, state}
    end
  end

  defp push_frame(ids_to_tracks, id, frame) do
    Map.update!(ids_to_tracks, id, fn %Track{buffers: buffers} = track ->
      %Track{track | buffers: Qex.push(buffers, frame)}
    end)
  end

  defp all_has_frame?(ids_to_tracks) do
    any_empty? =
      ids_to_tracks
      |> Map.values()
      |> Enum.map(fn %Track{buffers: buffers} -> buffers end)
      |> Enum.any?(&Enum.empty?/1)

    not any_empty?
  end

  defp get_ids_to_frames(ids_to_tracks) do
    ids_to_tracks
    |> Enum.map(fn {id, %Track{buffers: buffers}} -> {id, Qex.first!(buffers)} end)
    |> Map.new()
  end

  defp pop_frames(ids_to_tracks) do
    ids_to_tracks
    |> Enum.map(fn {id, %Track{buffers: buffers} = track} ->
      {id, %Track{track | buffers: Qex.pop!(buffers) |> elem(1)}}
    end)
    |> Map.new()
  end

  defp remove_ended_videos(
         %{ids_to_tracks: ids_to_tracks, internal_state: internal_state} = state
       ) do
    {ids_to_tracks, internal_state} =
      ids_to_tracks
      |> Enum.reduce(
        {ids_to_tracks, internal_state},
        fn {id, %Track{state: status, buffers: buffers}}, {ids_to_tracks, internal_state} ->
          if status == :end_of_stream and Enum.empty?(buffers) do
            ids_to_tracks = Map.delete(ids_to_tracks, id)
            {:ok, internal_state} = state.compositor_module.remove_video(id, internal_state)
            {ids_to_tracks, internal_state}
          else
            {ids_to_tracks, internal_state}
          end
        end
      )

    %{state | ids_to_tracks: ids_to_tracks, internal_state: internal_state}
  end

  # defp _remove_video(%{ids_to_tracks: ids_to_tracks, internal_state: internal_state} = state, id) do
  #   ids_to_tracks = Map.delete(ids_to_tracks, id)
  #   {:ok, internal_state} = state.compositor_module.remove_video(id, internal_state)
  #   %{state | ids_to_tracks: ids_to_tracks, internal_state: internal_state}
  # end

  defp update_track_status(ids_to_tracks, id, status) do
    ids_to_tracks
    |> Map.update!(id, fn track -> %Track{track | state: status} end)
  end

  defp all_streams_ended?(ids_to_tracks) do
    Enum.empty?(ids_to_tracks) or
      Enum.all?(ids_to_tracks, fn {_id, %Track{state: state}} -> state == :end_of_stream end)
  end

  @impl true
  def handle_end_of_stream(
        pad,
        _context,
        %{ids_to_tracks: ids_to_tracks, pads_to_ids: {_new_id, pads_to_ids}} = state
      ) do
    id = Map.get(pads_to_ids, pad)

    ids_to_tracks = ids_to_tracks |> update_track_status(id, :end_of_stream)
    state = %{state | ids_to_tracks: ids_to_tracks}

    if all_streams_ended?(ids_to_tracks) do
      {{:ok, end_of_stream: :output}, state}
    else
      {:ok, state}
    end
  end

  @spec determine_compositor_module(atom()) :: module()
  defp determine_compositor_module(implementation) do
    case implementation do
      # :ffmpeg ->
      #   Membrane.VideoCompositor.FFMPEG

      # :opengl ->
      #   Membrane.VideoCompositor.OpenGL

      # :nx ->
      #   Membrane.VideoCompositor.Nx

      # :ffmpeg_research ->
      #   Membrane.VideoCompositor.FFmpeg.Research

      _other ->
        implementation
    end
  end
end
