defmodule Membrane.VideoCompositor.MultipleInputs.VideoCompositor do
  @moduledoc """
  The element responsible for placing the first received frame
  above the other and sending forward buffer with
  merged frame binary in the payload.
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.MultipleInputs.VideoCompositor.Implementations
  alias Membrane.VideoCompositor.MultipleInputs.VideoCompositor.Track

  def_options implementation: [
                type: :atom,
                spec: Implementations.implementation_t() | {:mock, module()},
                description: "Implementation of video composer."
              ],
              caps: [
                type: RawVideo,
                description: "Struct with video width, height, framerate and pixel format."
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    availability: :on_request,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420},
    options: [
      position: [
        type: :tuple,
        spec: {integer(), integer()},
        description:
          "Initial position of the video on the screen, given in the pixels, relative to the upper left corner of the screen",
        default: {0, 0}
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}

  @impl true
  def handle_init(options) do
    compositor_module = determine_compositor_module(options.implementation)

    {:ok, internal_state} = compositor_module.init(options.caps)

    state = %{
      ids_to_tracks: %{},
      caps: options.caps,
      compositor_module: compositor_module,
      internal_state: internal_state,
      pads_to_ids: %{},
      new_pad_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, state.caps}}, state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    position = context.options.position

    state = register_track(state, pad, position)
    {:ok, state}
  end

  defp register_track(state, pad, position) do
    new_id = state.new_pad_id

    state = %{
      state
      | pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }

    %{state | ids_to_tracks: Map.put(state.ids_to_tracks, new_id, %Track{position: position})}
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      internal_state: internal_state,
      ids_to_tracks: ids_to_tracks
    } = state

    id = Map.get(pads_to_ids, pad)

    position = Map.get(ids_to_tracks, id).position
    {:ok, internal_state} = state.compositor_module.add_video(id, caps, position, internal_state)

    state = %{state | internal_state: internal_state}
    {:ok, state}
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        state
      ) do
    %{
      ids_to_tracks: ids_to_tracks,
      pads_to_ids: pads_to_ids
    } = state

    id = Map.get(pads_to_ids, pad)

    ids_to_tracks = push_frame(ids_to_tracks, id, buffer)

    state = %{state | ids_to_tracks: ids_to_tracks}

    case merge_frames(state) do
      {{:merged, buffers}, state} -> {{:ok, buffer: {:output, buffers}}, state}
      {{:empty, _empty}, state} -> {:ok, state}
    end
  end

  defp merge_frames(state) do
    %{
      ids_to_tracks: ids_to_tracks,
      internal_state: internal_state
    } = state

    if all_tracks_ready_to_merge?(ids_to_tracks) do
      ids_to_frames = get_ids_to_frames(ids_to_tracks)

      {{:ok, merged_frame_binary}, internal_state} =
        state.compositor_module.merge_frames(ids_to_frames, internal_state)

      ids_to_tracks = pop_frames(ids_to_tracks)

      state = %{
        state
        | ids_to_tracks: ids_to_tracks,
          internal_state: internal_state
      }

      state = remove_finished_tracks(state)

      {{_status, tail}, state} = merge_frames(state)
      merged = [%Membrane.Buffer{payload: merged_frame_binary}] ++ tail

      {{:merged, merged}, state}
    else
      {{:empty, []}, state}
    end
  end

  defp push_frame(ids_to_tracks, id, frame) do
    Map.update!(ids_to_tracks, id, fn track ->
      Track.push_frame(track, frame)
    end)
  end

  defp all_tracks_ready_to_merge?(ids_to_tracks) when map_size(ids_to_tracks) == 0 do
    false
  end

  defp all_tracks_ready_to_merge?(ids_to_tracks) do
    ids_to_tracks
    |> Map.values()
    |> Enum.all?(&Track.has_frame?/1)
  end

  defp get_ids_to_frames(ids_to_tracks) do
    ids_to_tracks
    |> Enum.map(fn {id, %Track{} = track} -> {id, Track.first_frame(track)} end)
    |> Enum.sort()
  end

  defp pop_frames(ids_to_tracks) do
    ids_to_tracks
    |> Enum.map(fn {id, %Track{} = track} ->
      {id, Track.pop_frame(track)}
    end)
    |> Map.new()
  end

  defp remove_finished_tracks(state) do
    state.ids_to_tracks
    |> Enum.reduce(
      state,
      fn {id, %Track{} = track}, state ->
        if Track.finished?(track) do
          remove_track(state, id)
        else
          state
        end
      end
    )
  end

  defp track_finished?(ids_to_tracks, id) do
    track = Map.get(ids_to_tracks, id)
    Track.finished?(track)
  end

  defp remove_track(state, id) do
    %{ids_to_tracks: ids_to_tracks, internal_state: internal_state} = state
    ids_to_tracks = Map.delete(ids_to_tracks, id)
    {:ok, internal_state} = state.compositor_module.remove_video(id, internal_state)
    %{state | ids_to_tracks: ids_to_tracks, internal_state: internal_state}
  end

  defp update_track_status(ids_to_tracks, id, status) do
    ids_to_tracks
    |> Map.update!(id, fn track -> %Track{track | status: status} end)
  end

  defp tracks_status(ids_to_tracks) do
    if Map.values(ids_to_tracks) |> Enum.all?(&Track.finished?/1) do
      :all_finished
    else
      :still_ongoing
    end
  end

  @impl true
  def handle_end_of_stream(
        pad,
        _context,
        state
      ) do
    %{ids_to_tracks: ids_to_tracks, pads_to_ids: pads_to_ids} = state
    id = Map.get(pads_to_ids, pad)

    ids_to_tracks = ids_to_tracks |> update_track_status(id, :end_of_stream)
    state = %{state | ids_to_tracks: ids_to_tracks}

    state =
      if track_finished?(ids_to_tracks, id) do
        remove_track(state, id)
      else
        state
      end

    {{buffers_status, buffers}, state} = merge_frames(state)

    case {buffers_status, tracks_status(state.ids_to_tracks)} do
      {:empty, :still_ongoing} ->
        {:ok, state}

      {:empty, :all_finished} ->
        {{:ok, end_of_stream: :output}, state}

      {:merged, :still_ongoing} ->
        {{:ok, buffer: {:output, buffers}}, state}

      {:merged, :all_finished} ->
        {{:ok, buffer: {:output, buffers}, end_of_stream: :output}, state}
    end
  end

  defp determine_compositor_module(implementation) do
    case implementation do
      {:mock, module} ->
        module

      implementation ->
        case Implementations.get_implementation_module(implementation) do
          {:ok, module} -> module
          {:error, error} -> raise error
        end
    end
  end
end
