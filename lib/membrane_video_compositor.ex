defmodule Membrane.VideoCompositor do
  @moduledoc """
  Element responsible for placing first received frame above the other and sending forward
  buffer with merged frame binary in payload.
  """

  use Membrane.Filter
  alias Membrane.Buffer
  alias Membrane.RawVideo

  def_options implementation: [
                type: :atom,
                description: "Implementation type of video composer."
              ],
              caps: [
                type: RawVideo,
                desciption: "Struct with video width, height, framerate and pixel format."
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
  @spec handle_init(%{
          implementation: :ffmpeg | :opengl | :nx,
          caps: RawVideo
        }) ::
          {:ok, map()}
  def handle_init(options) do
    state = %{
      pads: %{first_input: :queue.new(), second_input: :queue.new()},
      streams_state: %{first_input: :playing, second_input: :playing},
      caps: options.caps,
      compositor_module: determine_compositor_module(options.implementation)
    }

    {:ok, state_of_init_module} = state.compositor_module.init(state.caps)

    Map.put(state, :state_of_init_module, state_of_init_module)

    {:ok, state}
  end

  @impl true
  def handle_process(pad, buffer, _context, state) do
    updated_queue = Map.get(state.pads, pad)
    updated_queue = :queue.in(buffer, updated_queue)
    updated_pads = state.pads
    updated_pads = Map.replace!(updated_pads, pad, updated_queue)
    state = %{state | pads: updated_pads}

    case {:queue.out(state.pads.first_input), :queue.out(state.pads.second_input)} do
      {{{:value, first_frame_buffer}, rest_of_first_queue},
       {{:value, second_frame_buffer}, rest_of_second_queue}} ->
        frames_binaries = %{
          first_frame_binary: first_frame_buffer.payload,
          second_frame_binary: second_frame_buffer.payload
        }

        {:ok, merged_frame_binary} =
          state.compositor_module.merge_frames(frames_binaries, state.caps)

        merged_image_buffer = %Buffer{first_frame_buffer | payload: merged_frame_binary}
        pads = %{first_input: rest_of_first_queue, second_input: rest_of_second_queue}
        state = %{state | pads: pads}
        {{:ok, buffer: {:output, merged_image_buffer}}, state}

      _one_of_queues_is_empty ->
        {:ok, state}
    end
  end

  @impl true
  def handle_caps(_pad, %RawVideo{} = caps, _context, state) do
    caps = %{caps | height: caps.height * 2}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, state) do
    updated_streams_state = state.streams_state
    updated_streams_state = Map.replace!(updated_streams_state, pad, :end_of_the_stream)
    state = %{state | streams_state: updated_streams_state}

    case {state.streams_state.first_input, state.streams_state.second_input} do
      {:end_of_the_stream, :end_of_the_stream} ->
        # TO DO change for logger
        Membrane.Logger.bare_log(:info, "Processing ended")
        {{:ok, end_of_stream: :output, notify: {:end_of_stream, pad}}, state}

      _one_streams_has_not_ended ->
        {:ok, state}
    end
  end

  @spec determine_compositor_module(:ffmpeg | :opengl | :nx) :: module()
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
