defmodule Membrane.VideoCompositor do
  @moduledoc """
  Element responsible for placing first received frame
  above the other and sending forward buffer with
  merged frame binary in payload.
  """

  use Membrane.Filter
  alias Membrane.Buffer
  alias Membrane.RawVideo

  def_options implementation: [
                type: :atom,
                spec: :ffmpeg | :opengl | :nx,
                description: "Implementation type of video composer."
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
    state = %{
      pads: %{first_input: :queue.new(), second_input: :queue.new()},
      streams_state: %{first_input: :playing, second_input: :playing},
      caps: options.caps,
      compositor_module: determine_compositor_module(options.implementation)
    }

    {:ok, state_of_init_module} = state.compositor_module.init(state.caps)
    state = Map.put(state, :state_of_init_module, state_of_init_module)

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

        {:ok, merged_frame_binary} =
          state.compositor_module.merge_frames(frames_binaries, state.state_of_init_module)

        merged_image_buffer = %Buffer{first_frame_buffer | payload: merged_frame_binary}
        pads = %{first_input: rest_of_first_queue, second_input: rest_of_second_queue}
        state = %{state | pads: pads}
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

  @spec determine_compositor_module(atom()) :: module()
  defp determine_compositor_module(implementation) do
    case implementation do
      :ffmpeg ->
        Membrane.VideoCompositor.FFMPEG

      :opengl ->
        Membrane.VideoCompositor.OpenGL

      :nx ->
        Membrane.VideoCompositor.Nx

      _other ->
        raise "#{implementation} is not available implementation."
    end
  end
end
