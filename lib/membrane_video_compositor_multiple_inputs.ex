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
    defstruct buffers: :queue.new(), state: :playing
  end

  @impl true
  def handle_init(options) do
    compositor_module = determine_compositor_module(options.implementation)

    {:ok, internal_state} = compositor_module.init(options.caps)

    state = %{
      tracks: %{},
      caps: options.caps,
      compositor_module: compositor_module,
      internal_state: internal_state,
      pads_to_id: {0, %{}}
    }

    {:ok, state}
  end

  @impl true
  def handle_pad_added(pad, _context, state) do
    {new_id, pads_to_id} = state.pads_to_id
    state = %{state | pads_to_id: {new_id + 1, Map.put(pads_to_id, pad, new_id)}}

    state = %{state | tracks: Map.put(state.tracks, pad, %Track{})}
    {:ok, state}
  end

  @impl true
  def handle_caps(pad, caps, _context, %{pads_to_id: {_new_id, pads_to_id}} = state) do
    id = Map.get(pads_to_id, pad)
    {:ok, internal_state} = state.compositor_module.add_video(id, caps, %{x: 0, y: 0})
    state = %{state | internal_state: internal_state}
    {{:ok, caps: {:output, state.caps}}, state}
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        %{tracks: tracks, internal_state: internal_state} = state
      ) do
    tracks =
      Map.update!(tracks, pad, fn %Track{buffers: buffers} = track ->
        %Track{track | buffers: Qex.push(buffers, buffer)}
      end)

    state = %{state | tracks: tracks}

    any_empty? =
      tracks
      |> Enum.map(fn %Track{buffers: buffers} -> buffers end)
      |> Enum.all?(&Enum.empty?/1)

    all_empty? = not any_empty?

    if all_empty? do
      all_frames =
        tracks
        |> Enum.map(fn %Track{buffers: buffers} -> buffers end)
        |> Enum.map(&Qex.first!/1)

      {{:ok, merged_frame_binary}, internal_state} =
        state.compositor_module.merge_frames(all_frames, internal_state)

      tracks =
        tracks
        |> Enum.map(fn %Track{buffers: buffers} = track ->
          %Track{track | buffers: Qex.pop!(buffers) |> elem(1)}
        end)

      state = %{
        state
        | tracks: tracks,
          internal_state: internal_state
      }

      {{:ok, buffer: {:output, merged_frame_binary}}, state}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_end_of_stream(pad, _context, %{streams_state: streams_state} = state) do
    streams_state = Map.put(streams_state, pad, :end_of_the_stream)
    state = %{state | streams_state: streams_state}

    all_ended? =
      streams_state |> Enum.all?(fn {_pad, stream_state} -> stream_state == :end_of_stream end)

    if all_ended? do
      {{:ok, end_of_stream: :output, notify: {:end_of_stream, pad}}, state}
    else
      {:ok, state}
    end
  end

  @spec determine_compositor_module(atom()) :: module()
  defp determine_compositor_module(implementation) do
    case implementation do
      :ffmpeg ->
        Membrane.VideoCompositor.FFMPEG

      # :opengl ->
      #   Membrane.VideoCompositor.OpenGL

      # :nx ->
      #   Membrane.VideoCompositor.Nx

      # :ffmpeg_research ->
      #   Membrane.VideoCompositor.FFmpeg.Research

      _other ->
        raise "#{implementation} is not available implementation."
    end
  end
end
