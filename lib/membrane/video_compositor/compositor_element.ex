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
  alias Membrane.VideoCompositor.RustStructs.VideoPlacement
  alias Membrane.VideoCompositor.VideoTransformations
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
      initial_placement: [
        spec: VideoPlacement.t(),
        description: "Initial placement of the video on the screen"
      ],
      timestamp_offset: [
        spec: Membrane.Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      initial_video_transformations: [
        spec: VideoTransformations.t(),
        description:
          "Specify the initial types and the order of transformations applied to video.",
        # Can't set here struct, due to quote error (AST invalid node).
        # Calling Macro.escape() returns tuple and makes code more error prone and less readable.
        default: nil
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
      initial_video_placements: %{},
      initial_video_transformations: %{},
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

    initial_placement = context.options.initial_placement

    initial_transformations =
      case context.options.initial_video_transformations do
        nil ->
          VideoTransformations.get_empty_video_transformations()

        _other ->
          context.options.initial_video_transformations
      end

    state = register_pad(state, pad, initial_placement, initial_transformations, timestamp_offset)
    {:ok, state}
  end

  defp register_pad(state, pad, placement, transformations, timestamp_offset) do
    new_id = state.new_pad_id

    %{
      state
      | initial_video_placements: Map.put(state.initial_video_placements, new_id, placement),
        initial_video_transformations:
          Map.put(state.initial_video_transformations, new_id, transformations),
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
      initial_video_placements: initial_video_placements,
      initial_video_transformations: initial_video_transformations
    } = state

    id = Map.get(pads_to_ids, pad)

    {initial_video_placements, initial_video_transformations} =
      case {Map.pop(initial_video_placements, id), Map.pop(initial_video_transformations, id)} do
        {{nil, initial_video_placements}, {nil, initial_video_transformations}} ->
          # this video was added before
          :ok = Wgpu.update_caps(wgpu_state, id, caps)
          {initial_video_placements, initial_video_transformations}

        {{placement, initial_video_placements}, {transformations, initial_video_transformations}} ->
          # this video was waiting for first caps to be added to the compositor
          :ok = Wgpu.add_video(wgpu_state, id, caps, placement, transformations)
          {initial_video_placements, initial_video_transformations}
      end

    {
      :ok,
      %{
        state
        | initial_video_placements: initial_video_placements,
          initial_video_transformations: initial_video_transformations
      }
    }
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

  @impl true
  def handle_other({:update_placement, placements}, _ctx, state) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state
    } = state

    for {pad, placement} <- placements do
      id = Map.get(pads_to_ids, pad)

      Wgpu.update_placement(wgpu_state, id, placement)
    end

    {:ok, state}
  end

  @impl true
  def handle_other({:update_transformations, all_transformations}, _ctx, state) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state
    } = state

    for {pad, video_transformations} <- all_transformations do
      id = Map.get(pads_to_ids, pad)

      Wgpu.update_transformations(wgpu_state, id, video_transformations)
    end

    {:ok, state}
  end
end
