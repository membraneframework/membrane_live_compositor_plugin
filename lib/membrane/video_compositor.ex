defmodule Membrane.VideoCompositor do
  @moduledoc """
  The element responsible for placing the first received frame
  above the other and sending forward buffer with
  merged frame binary in the payload.
  """

  use Membrane.Filter
  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Implementations

  def_options implementation: [
                type: :atom,
                spec: Implementations.implementation_t(),
                description: "Implementation of video composer."
              ],
              caps: [
                type: RawVideo,
                description: "Struct with video width, height, framerate and pixel format."
              ]

  def_input_pad(:first_input,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}
  )

  def_input_pad(:second_input,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}
  )

  def_output_pad(:output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}
  )

  @impl true
  def handle_init(options) do
    {:ok, compositor_module} = Implementations.get_implementation_module(options.implementation)

    {:ok, internal_state} = compositor_module.init(options.caps)

    state = %{
      pads: %{first_input: :queue.new(), second_input: :queue.new()},
      streams_state: %{first_input: :playing, second_input: :playing},
      caps: options.caps,
      compositor_module: compositor_module,
      internal_state: internal_state
    }

    {:ok, state}
  end

  @impl true
  def handle_process(pad, buffer, _context, %{pads: pads} = state) do
    updated_queue = Map.get(pads, pad)
    updated_queue = :queue.in(buffer, updated_queue)
    pads = Map.replace!(pads, pad, updated_queue)
    state = %{state | pads: pads}

    case {:queue.out(state.pads.first_input), :queue.out(state.pads.second_input)} do
      {{{:value, first_frame_buffer}, rest_of_first_queue},
       {{:value, second_frame_buffer}, rest_of_second_queue}} ->
        frames_binaries = %{
          first: first_frame_buffer.payload,
          second: second_frame_buffer.payload
        }

        {{:ok, merged_frame_binary}, internal_state} =
          state.compositor_module.merge_frames(frames_binaries, state.internal_state)

        merged_image_buffer = %Buffer{first_frame_buffer | payload: merged_frame_binary}
        pads = %{first_input: rest_of_first_queue, second_input: rest_of_second_queue}
        state = %{state | pads: pads, internal_state: internal_state}
        {{:ok, buffer: {:output, merged_image_buffer}}, state}

      _one_of_queues_is_empty ->
        {:ok, state}
    end
  end

  @impl true
  def handle_caps(:first_input, %RawVideo{} = caps, _context, state) do
    caps = %{caps | height: caps.height * 2}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_caps(:second_input, %RawVideo{} = _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, %{streams_state: streams_state} = state) do
    streams_state = Map.put(streams_state, pad, :end_of_the_stream)
    state = %{state | streams_state: streams_state}

    case {streams_state.first_input, streams_state.second_input} do
      {:end_of_the_stream, :end_of_the_stream} ->
        {{:ok, end_of_stream: :output, notify: {:end_of_stream, pad}}, state}

      _one_streams_has_not_ended ->
        {:ok, state}
    end
  end
end
