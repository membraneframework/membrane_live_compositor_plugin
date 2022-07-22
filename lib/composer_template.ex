defmodule SimpleComposerDemo.Elements.Composer do
  @moduledoc """
  Element responsible for placing first recived frame above the other and sending forward
  buffor with merged frame binary in payload.
  handle_init: initialize two Erlang :queue-s,
  handle_process:
    1. puts recived frame and saves it to appropriate queue (based on from with input pad it recived frame)
    2. checks whether there are elements in both queues, if so it runs merge_frames(first_frame_binary, second_frame_binary) function
    3. wraps binary of merged frame into buffer
    4. sends forward (to encoder or sink pad) wraped buffer
  handle_caps: handle caps differences between input pads and output pad
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.Buffer

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

  def_options(
    backend: [
      type: :atom,
      description:
        "Backend of the composer. Currently supported backends are: [:ffmpeg, :opengl, :nx]",
      default: :ffmpeg
    ]
  )

  '''
              input_width: [
                type: :int,
                description: "Width of input frames (must be the same for both frames)",
                default: 1280
              ],
              input_height: [
                type: :int,
                description: "Height of input frames (must be the same for both frames)",
                default: 720
              ],
              input_bands: [
                type: :int,
                description: "Bands of input frames (must be the same for both frames)",
                default: 3
              ]
  '''

  @impl true
  def handle_init(_options) do
    state = %{
      frames_queues: %{first_queue: :queue.new(), second_queue: :queue.new(), backend: :ffmpeg}
    }

    {:ok, state}
  end

  @impl true
  def handle_process(pad, buffer, _contex, state) do
    # updates state with new queue
    state =
      cond do
        # it's boilerplate, but it works
        pad == :first_input ->
          updated_first_queue = state.frames_queues.first_queue
          updated_first_queue = :queue.in(buffer, updated_first_queue)
          updated_frames_queues = state.frames_queues
          updated_frames_queues = %{updated_frames_queues | first_queue: updated_first_queue}
          %{state | frames_queues: updated_frames_queues}

        pad == :second_input ->
          updated_second_queue = state.frames_queues.second_queue
          updated_second_queue = :queue.in(buffer, updated_second_queue)
          updated_frames_queues = state.frames_queues
          updated_frames_queues = %{updated_frames_queues | second_queue: updated_second_queue}
          %{state | frames_queues: updated_frames_queues}
      end

    case {:queue.out(state.frames_queues.first_queue),
          :queue.out(state.frames_queues.second_queue)} do
      # checks if both queues are not empty
      {{{:value, first_frame_buffer}, rest_of_first_queue},
       {{:value, second_frame_buffer}, rest_of_second_queue}} ->
        {:ok, merged_frame_binary} =
          merge_frames(first_frame_buffer.payload, second_frame_buffer.payload, state.backend)

        # packs merged binary into buffer (for encoder)
        merged_image_buffer = %Buffer{first_frame_buffer | payload: merged_frame_binary}
        # updates queues (removes processed frames)
        frames_queues = %{first_queue: rest_of_first_queue, second_queue: rest_of_second_queue}
        # updates state with reduced queues
        state = %{state | frames_queues: frames_queues}
        # sends buffer to encoder
        {{:ok, buffer: {:output, merged_image_buffer}}, state}

      # one of queues is empty
      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_caps(:first_input, %RawVideo{width: 1280, height: 720} = caps, _context, state) do
    caps = %{caps | height: caps.height * 2}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_caps(:second_input, %RawVideo{width: 1280, height: 720} = caps, _context, state) do
    caps = %{caps | height: caps.height * 2}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_end_of_stream(pad, _context, state) do
    state =
      cond do
        pad == :first_input ->
          updated_frames_queues = state.frames_queues
          updated_frames_queues = %{updated_frames_queues | first_queue: :end_of_the_stream}
          %{state | frames_queues: updated_frames_queues}

        pad == :second_input ->
          updated_frames_queues = state.frames_queues
          updated_frames_queues = %{updated_frames_queues | second_queue: :end_of_the_stream}
          %{state | frames_queues: updated_frames_queues}
      end

    case {state.frames_queues.first_queue, state.frames_queues.second_queue} do
      # when both stream ended
      {:end_of_the_stream, :end_of_the_stream} ->
        {{:ok, end_of_stream: :output, notify: {:end_of_stream, pad}}, state}

      # when only one of the streams ended
      _ ->
        {:ok, state}
    end
  end

  defp merge_frames(_first_frame_binary, _second_frame_binary, :ffmpeg) do
    # TO DO: implement function, that merge two raw video, 1280x720, I420 encoded frames,
    # into raw video, 1280x720, I420 encoded frame
    {:error, :not_implemented}
  end

  defp merge_frames(_first_frame_binary, _second_frame_binary, :nx) do
    # TO DO: implement function, that merge two raw video, 1280x720, I420 encoded frames,
    # into raw video, 1280x720, I420 encoded frame
    {:error, :not_implemented}
  end

  defp merge_frames(_first_frame_binary, _second_frame_binary, :opengl) do
    # TO DO: implement function, that merge two raw video, 1280x720, I420 encoded frames,
    # into raw video, 1280x1440, I420 encoded frame
    {:error, :not_implemented}
  end
end
