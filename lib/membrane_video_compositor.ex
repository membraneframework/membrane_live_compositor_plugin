defmodule Membrane.VideoCompositor do
  @moduledoc """
  Element responsible for placing first recived frame above the other and sending forward
  buffor with merged frame binary in payload.
  handle_init: initialize two Erlang :queue-s,
  handle_process:
    1. puts recived frame and saves it to appropriate queue (based on from with input pad it recived frame)
    2. checks whether there are elements in both queues, if so it runs
    Membrane.VideoCompositor.FrameCompositor.merge_frames(first_frame_binary, second_frame_binary, implementation) function
    3. wraps binary of merged frame into buffer
    4. sends forward (to encoder or sink pad) wraped buffer
  handle_caps: handle caps differences between input pads and output pad
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.Buffer

  def_options implementation: [
                type: :atom,
                description:
                  "Implementation type of video composer. One of: :ffmpeg, :opengl, :nx"
              ],
              video_width: [
                type: :int,
                description: "Width of input videos"
              ],
              video_height: [
                type: :int,
                description: "Height of input videos"
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
      frames_queues: %{first_input: :queue.new(), second_input: :queue.new()},
      streams_state: %{first_input: :playing, second_input: :playing},
      implementation: options.implementation,
      video_width: options.video_width,
      video_height: options.video_height
    }

    {:ok, state}
  end

  @impl true
  def handle_process(pad, buffer, _contex, state) do
    updated_queue = Map.get(state.frames_queues, pad)
    updated_queue = :queue.in(buffer, updated_queue)
    updated_frames_queues = state.frames_queues
    updated_frames_queues = Map.replace!(updated_frames_queues, pad, updated_queue)
    state = %{state | frames_queues: updated_frames_queues}

    case {:queue.out(state.frames_queues.first_input),
          :queue.out(state.frames_queues.second_input)} do
      {{{:value, first_frame_buffer}, rest_of_first_queue},
       {{:value, second_frame_buffer}, rest_of_second_queue}} ->
        {:ok, merged_frame_binary} =
          Membrane.VideoCompositor.FrameCompositor.merge_frames(
            first_frame_buffer.payload,
            second_frame_buffer.payload,
            state.implementation,
            state.video_width,
            state.video_height
          )

        merged_image_buffer = %Buffer{first_frame_buffer | payload: merged_frame_binary}
        frames_queues = %{first_input: rest_of_first_queue, second_input: rest_of_second_queue}
        state = %{state | frames_queues: frames_queues}
        {{:ok, buffer: {:output, merged_image_buffer}}, state}

      # one of queues is empty
      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_caps(:first_input, %RawVideo{} = caps, _context, state) do
    caps = %{caps | height: caps.height * 2}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_caps(:second_input, %RawVideo{} = caps, _context, state) do
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
        {{:ok, end_of_stream: :output, notify: {:end_of_stream, pad}}, state}

      _ ->
        {:ok, state}
    end
  end
end
