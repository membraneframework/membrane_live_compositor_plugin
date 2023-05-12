defmodule Membrane.VideoCompositor.Queue.Offline.Element do
  @moduledoc false

  use Membrane.Filter

  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.State
  alias Membrane.VideoCompositor.Queue.State.PadState
  alias Membrane.VideoCompositor.Scene.{MockCallbacks, VideoConfig}

  def_options target_fps: [
                spec: RawVideo.framerate_t()
              ]

  def_input_pad :input,
    availability: :on_request,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420},
    options: [
      timestamp_offset: [
        spec: Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      video_config: [
        spec: VideoConfig.t(),
        description: "Specify layout and transformations of the video on final scene."
      ]
    ]

  def_output_pad :compositor_core,
    demand_mode: :auto,
    accepted_format: %CompositorCoreFormat{}

  @type compositor_actions :: [
          Membrane.Element.Action.stream_format_t()
          | State.notify_compositor_scene()
          | Membrane.Element.Action.buffer_t()
        ]

  @impl true
  def handle_init(_ctx, _options = %{target_fps: target_fps}) do
    {[], %State{target_fps: target_fps}}
  end

  @impl true
  def handle_pad_added(pad, context, state = %State{}) do
    state = Bunch.Struct.put_in(state, [:pads_states, pad], PadState.new(context.options))
    {[], state}
  end

  @impl true
  def handle_pad_removed(pad, _ctx, state = %State{}) do
    state = Bunch.Struct.put_in(state, [:pads_states, pad, :events_queue], :end_of_stream)

    pop_frames_while_all_pads_ready({[], state})
  end

  @impl true
  def handle_stream_format(pad, stream_format, _context, state = %State{}) do
    state =
      Bunch.Struct.update_in(
        state,
        [:pads_states, pad, :events_queue],
        &(&1 ++ [{:stream_format, stream_format}])
      )

    {[], state}
  end

  @impl true
  def handle_process(pad, buffer, _context, state = %State{}) do
    frame_pts = buffer.pts + Bunch.Struct.get_in(state, [:pads_states, pad, :timestamp_offset])

    state =
      state
      |> Bunch.Struct.update_in(
        [:pads_states, pad, :events_queue],
        &(&1 ++ [{:frame, frame_pts, buffer.payload}])
      )

    if state.pads_states == %{} do
      {[end_of_stream: :compositor_core], state}
    else
      pop_frames_while_all_pads_ready({[], state})
    end
  end

  # @impl true
  # def handle_parent_notification(
  #       {:update_scene, scene = %Scene{}},
  #       _ctx,
  #       state = %State{most_recent_frame_pts: most_recent_frame_pts}
  #     ) do
  #   state = State.register_event(state, :pad_added, {most_recent_frame_pts, scene})
  #   {[], state}
  # end

  @spec next_interval_end(State.t()) :: Time.non_neg_t()
  defp next_interval_end(%State{
         previous_interval_end_pts: previous_interval_end_pts,
         target_fps: {fps_num, fps_den}
       }) do
    if previous_interval_end_pts == nil do
      0
    else
      previous_interval_end_pts + Kernel.ceil(1_000_000_000 * fps_den / fps_num)
    end
  end

  @spec pop_frames_while_all_pads_ready({compositor_actions(), State.t()}) ::
          {compositor_actions(), State.t()}
  defp pop_frames_while_all_pads_ready({actions, state}) do
    if all_pads_queues_ready?(state) do
      handle_all_pads_queues_ready(state)
      |> pop_frames_while_all_pads_ready()
      |> then(fn {new_actions, state} -> {actions ++ new_actions, state} end)
    else
      {actions, state}
    end
  end

  @spec handle_all_pads_queues_ready(State.t()) ::
          {compositor_actions(), State.t()}
  defp handle_all_pads_queues_ready(
         state = %State{current_output_format: last_output_format, current_scene: last_scene}
       ) do
    pts = next_interval_end(state)

    {pads_frames, state} = pop_events(state, pts)

    stream_format_action =
      case state.current_output_format do
        ^last_output_format -> []
        new_output_format -> [stream_format: {:compositor_core, new_output_format}]
      end

    scene_action =
      case state.current_scene do
        ^last_scene -> []
        new_scene -> [notify_child: {:compositor, {:update_scene, new_scene}}]
      end

    buffer = %Buffer{
      payload: pads_frames,
      pts: pts,
      dts: pts
    }

    buffer_action = [buffer: {:compositor_core, buffer}]

    state = %State{state | previous_interval_end_pts: pts}
    state = drop_eos_pads(state)

    {stream_format_action ++ scene_action ++ buffer_action, state}
  end

  @spec all_pads_queues_ready?(State.t()) :: boolean()
  defp all_pads_queues_ready?(state = %State{pads_states: pads_states}) do
    interval_end = next_interval_end(state)

    Enum.all?(
      pads_states,
      fn {_pad, %PadState{events_queue: events_queue, timestamp_offset: timestamp_offset}} ->
        timestamp_offset > interval_end or
          Enum.any?(events_queue, fn event -> PadState.event_type(event) == :frame end)
      end
    )
  end

  @spec drop_eos_pads(State.t()) :: State.t()
  defp drop_eos_pads(
         state = %State{
           pads_states: pads_states,
           current_output_format: output_format,
           current_scene: scene
         }
       ) do
    eos_pads =
      pads_states
      |> Map.to_list()
      |> Enum.filter(fn {_pad, pad_state} -> eos_pad?(pad_state) end)
      |> Enum.map(fn {pad, _pad_state} -> pad end)

    pads_states = Map.drop(pads_states, eos_pads)
    output_format = Map.drop(output_format, eos_pads)

    scene =
      Enum.reduce(eos_pads, scene, fn pad, scene -> MockCallbacks.remove_video(scene, pad) end)

    %State{
      state
      | pads_states: pads_states,
        current_output_format: output_format,
        current_scene: scene
    }
  end

  @spec eos_pad?(PadState.t()) :: boolean()
  defp eos_pad?(%PadState{events_queue: events_queue}) do
    Enum.reduce_while(
      events_queue,
      false,
      fn event, _acc ->
        case PadState.event_type(event) do
          :frame -> {:halt, false}
          :end_of_stream -> {:halt, true}
          _other -> {:cont, false}
        end
      end
    )
  end

  @spec pop_events(State.t(), Time.non_neg_t()) ::
          {%{Pad.ref_t() => binary}, updated_state :: State.t()}
  defp pop_events(state = %State{pads_states: pads_states}, buffer_pts) do
    pads_states
    |> Map.to_list()
    |> Enum.filter(fn {_pad, %PadState{timestamp_offset: timestamp_offset}} ->
      timestamp_offset <= buffer_pts
    end)
    |> Enum.map_reduce(
      state,
      fn {pad, pad_state}, state ->
        {events_before_frame, {:frame, _pts, frame_data}, events_after_frame} =
          split_events_queue(pad_state)

        state = Bunch.Struct.put_in(state, [:pads_states, pad, :events_queue], events_after_frame)

        {{pad, frame_data}, handle_events(state, pad, events_before_frame)}
      end
    )
    |> then(fn {pads_frames, state} -> {Enum.into(pads_frames, %{}), state} end)
  end

  @spec handle_events(State.t(), Pad.ref_t(), [
          PadState.pad_added_event() | PadState.stream_format_event()
        ]) :: State.t()
  defp handle_events(state, pad, events) do
    Enum.reduce(
      events,
      state,
      fn event, state = %State{current_scene: current_scene} ->
        case event do
          {:pad_added, pad_options} ->
            Map.put(
              state,
              :current_scene,
              MockCallbacks.add_video(current_scene, pad, pad_options)
            )

          {:stream_format, pad_stream_format} ->
            Bunch.Struct.put_in(
              state,
              [:current_output_format, :pads_formats, pad],
              pad_stream_format
            )
        end
      end
    )
  end

  @spec split_events_queue(PadState.t()) ::
          {[PadState.pad_added_event() | PadState.stream_format_event()], PadState.frame_event(),
           [PadState.pad_event()]}
  defp split_events_queue(%PadState{events_queue: events_queue}) do
    {events_before_frame, [frame_event | events_after_frame]} =
      Enum.split_while(events_queue, fn event -> PadState.event_type(event) != :frame end)

    {events_before_frame, frame_event, events_after_frame}
  end
end
