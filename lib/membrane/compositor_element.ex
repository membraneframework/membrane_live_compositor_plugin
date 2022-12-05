defmodule Membrane.VideoCompositor.CompositorElement do
  @moduledoc """
  The element responsible for composing frames.

  It is capable of operating in one of two modes:

   * offline compositing:
     The compositor will wait for all videos to have a recent enough frame available and then perform the compositing.

   * real-time compositing:
     In this mode, if the compositor will start a timer ticking every spf (seconds per frame). The timer is reset every time a frame is produced.
     If the compositor doesn't have all frames ready by the time the timer ticks, it will produce a frame anyway, using old frames as fallback in cases when a current frame is not available.
     If the frames arrive later, they will be dropped. The newest dropped frame will become the new fallback frame.

  """

  use Membrane.Filter
  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Wgpu

  def_options caps: [
                spec: RawVideo.t(),
                description: "Struct with video width, height, framerate and pixel format."
              ],
              real_time: [
                spec: boolean(),
                description: """
                Set the compositor to real-time mode.
                """,
                default: false
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
      ],
      timestamp_offset: [
        spec: Membrane.Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}

  @impl true
  def handle_init(options) do
    {:ok, wgpu_state} = Wgpu.init(options.caps)

    state = %{
      videos_positions: %{},
      timestamp_offsets: %{},
      caps: options.caps,
      real_time: options.real_time,
      wgpu_state: wgpu_state,
      pads_to_ids: %{},
      new_pad_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    spf = spf_from_framerate(state.caps.framerate)

    actions =
      if state.real_time do
        [start_timer: {:render_frame, spf}, caps: {:output, state.caps}]
      else
        [caps: {:output, state.caps}]
      end

    {{:ok, actions}, state}
  end

  @impl true
  def handle_tick(:render_frame, _ctx, state) do
    {:ok, {frame, pts}} = Wgpu.force_render(state.wgpu_state)

    actions = [buffer: {:output, %Buffer{payload: frame, pts: pts}}]

    {{:ok, actions}, state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    timestamp_offset =
      case context.options.timestamp_offset do
        timestamp_offset when timestamp_offset < 0 ->
          raise ArgumentError,
            message:
              "Invalid timestamp_offset option for pad: #{Pad.name_by_ref(pad)}. timestamp_offset can't be negative."

        timestamp_offset ->
          timestamp_offset
      end

    position = context.options.position

    state = register_pad(state, pad, position, timestamp_offset)
    {:ok, state}
  end

  defp register_pad(state, pad, position, timestamp_offset) do
    new_id = state.new_pad_id

    %{
      state
      | videos_positions: Map.put(state.videos_positions, new_id, position),
        timestamp_offsets: Map.put(state.timestamp_offsets, new_id, timestamp_offset),
        pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      videos_positions: videos_positions
    } = state

    id = Map.get(pads_to_ids, pad)

    position = Map.get(videos_positions, id)
    :ok = Wgpu.put_video(wgpu_state, id, caps, position)

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
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      timestamp_offsets: timestamp_offsets
    } = state

    id = Map.get(pads_to_ids, pad)

    %Membrane.Buffer{payload: frame, pts: pts} = buffer
    pts = pts + Map.get(timestamp_offsets, id)

    case Wgpu.upload_frame(wgpu_state, id, {frame, pts}) do
      {:ok, {frame, pts}} ->
        {
          {
            :ok,
            [
              buffer: {
                :output,
                %Membrane.Buffer{payload: frame, pts: pts}
              }
            ] ++ restart_timer_action_if_necessary(state)
          },
          state
        }

      :ok ->
        {:ok, state}
    end
  end

  defp spf_from_framerate({frames, seconds}) do
    Ratio.new(frames, seconds)
  end

  defp restart_timer_action_if_necessary(state) do
    spf = spf_from_framerate(state.caps.framerate)

    if state.real_time do
      [stop_timer: :render_frame, start_timer: {:render_frame, spf}]
    else
      []
    end
  end

  @impl true
  def handle_end_of_stream(
        pad,
        context,
        state
      ) do
    %{pads_to_ids: pads_to_ids, wgpu_state: wgpu_state} = state
    id = Map.get(pads_to_ids, pad)

    :ok = Wgpu.send_end_of_stream(wgpu_state, id)

    actions =
      if all_input_pads_received_end_of_stream?(context.pads) do
        stop = if state.real_time, do: [stop_timer: :render_frame], else: []
        [end_of_stream: :output] ++ stop
      else
        []
      end

    {{:ok, actions}, state}
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end
end
