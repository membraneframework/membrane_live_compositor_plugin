defmodule Membrane.VideoCompositor.CompositorElement do
  @moduledoc """
  The element responsible for composing frames.

  It is capable of operating in one of two modes:

   * offline compositing:
     The compositor will wait for all videos to have a recent enough frame available and then perform the compositing.

   * live compositing:
     In this mode, if the compositor will start a timer ticking every spf (seconds per frame). The timer is reset every time a frame is produced.
     If the compositor doesn't have all frames ready by the time the timer ticks, it will produce a frame anyway, using old frames as fallback in cases when a current frame is not available.
     If the frames arrive later, they will be dropped.

  """

  use Membrane.Filter
  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Wgpu

  def_options caps: [
                spec: RawVideo.t(),
                description: "Struct with video width, height, framerate and pixel format."
              ],
              live: [
                spec: boolean(),
                description: """
                Set the compositor to live mode.
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
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}

  @impl true
  def handle_init(options) do
    {:ok, internal_state} = Wgpu.init(options.caps)

    state = %{
      video_positions_waiting_for_caps: %{},
      caps: options.caps,
      live: options.live,
      internal_state: internal_state,
      pads_to_ids: %{},
      new_pad_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    spf = spf_from_framerate(state.caps.framerate)

    actions =
      if state.live do
        [start_timer: {:render_frame, spf}, caps: {:output, state.caps}]
      else
        [caps: {:output, state.caps}]
      end

    {{:ok, actions}, state}
  end

  @impl true
  def handle_tick(:render_frame, _ctx, state) do
    {{:ok, {frame, pts}}, internal_state} = Wgpu.force_render(state.internal_state)

    {{:ok, buffer: {:output, %Buffer{payload: frame, pts: pts}}},
     %{state | internal_state: internal_state}}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    position = context.options.position

    state = register_pad(state, pad, position)
    {:ok, state}
  end

  defp register_pad(state, pad, position) do
    new_id = state.new_pad_id

    %{
      state
      | video_positions_waiting_for_caps:
          Map.put(state.video_positions_waiting_for_caps, new_id, position),
        pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      internal_state: internal_state,
      video_positions_waiting_for_caps: video_positions_waiting_for_caps
    } = state

    id = Map.get(pads_to_ids, pad)

    {position, video_positions_waiting_for_caps} = Map.pop!(video_positions_waiting_for_caps, id)
    {:ok, internal_state} = Wgpu.add_video(internal_state, id, caps, position)

    state = %{
      state
      | internal_state: internal_state,
        video_positions_waiting_for_caps: video_positions_waiting_for_caps
    }

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
      internal_state: internal_state
    } = state

    id = Map.get(pads_to_ids, pad)

    %Membrane.Buffer{payload: frame, pts: pts} = buffer

    case Wgpu.upload_frame(internal_state, id, {frame, pts}) do
      {{:ok, {frame, pts}}, internal_state} ->
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
          %{state | internal_state: internal_state}
        }

      {:ok, internal_state} ->
        {:ok, %{state | internal_state: internal_state}}
    end
  end

  defp spf_from_framerate({frames, seconds}) do
    Ratio.new(frames, seconds)
  end

  defp restart_timer_action_if_necessary(state) do
    spf = spf_from_framerate(state.caps.framerate)

    if state.live do
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
    %{pads_to_ids: pads_to_ids, internal_state: internal_state} = state
    id = Map.get(pads_to_ids, pad)

    {:ok, internal_state} = Wgpu.send_end_of_stream(internal_state, id)
    state = %{state | internal_state: internal_state}

    if all_input_pads_received_end_of_stream?(context.pads) do
      if state.live do
        {{:ok, end_of_stream: :output, stop_timer: :render_frame}, state}
      else
        {{:ok, end_of_stream: :output}, state}
      end
    else
      {:ok, state}
    end
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end
end
