defmodule Membrane.VideoCompositor.Queue.Offline.Element do
  @moduledoc false

  use Membrane.Filter

  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.State
  alias Membrane.VideoCompositor.Queue.State.{MockCallbacks, PadState}
  alias Membrane.VideoCompositor.Scene.VideoConfig

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
    state =
      Bunch.Struct.update_in(state, [:pads_states, pad, :events_queue], &(&1 ++ [:end_of_stream]))

    check_pads_queues({[], state})
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
      |> Map.update!(:most_recent_frame_pts, &max(&1, frame_pts))

    if state.pads_states == %{} do
      {[end_of_stream: :compositor_core], state}
    else
      check_pads_queues({[], state})
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
    previous_interval_end_pts + Kernel.ceil(1_000_000_000 * fps_den / fps_num)
  end

  defp frame_or_eos?(events_queue) do
    Enum.reduce_while(
      events_queue,
      false,
      fn event, _acc ->
        case PadState.event_type(event) do
          :frame -> {:halt, {true, :frame}}
          :end_of_stream -> {:halt, {true, :eos}}
          _other -> {:cont, false}
        end
      end
    )
  end

  defp all_queues_ready?(%State{
         pads_states: pads_states,
         previous_interval_end_pts: buffer_pts
       }) do
    pads_states
    |> Map.values()
    |> Enum.reduce_while(
      {false, false},
      fn %PadState{timestamp_offset: timestamp_offset, events_queue: events_queue},
         {any_frame?, _any_waiting_queue?} ->
        frame_or_eos = frame_or_eos?(events_queue)

        cond do
          frame_or_eos == {true, :frame} -> {:cont, {true, false}}
          frame_or_eos == {true, :eos} -> {:cont, {any_frame?, false}}
          timestamp_offset > buffer_pts -> {:cont, {any_frame?, false}}
          true -> {:halt, {any_frame?, true}}
        end
      end
    )
    |> then(fn {any_frame?, any_waiting_queue?} ->
      any_frame? and not any_waiting_queue?
    end)
  end

  @spec check_pads_queues({compositor_actions(), State.t()}) ::
          {compositor_actions(), State.t()}
  defp check_pads_queues({actions, state = %State{}}) do
    if all_queues_ready?(state) do
      handle_events(state)
      |> then(fn {new_actions, state} -> {actions ++ new_actions, state} end)
      |> check_pads_queues()
    else
      {actions, state}
    end
  end

  @spec handle_events(State.t()) :: {compositor_actions(), State.t()}
  defp handle_events(
         state = %State{pads_states: pads_states, previous_interval_end_pts: buffer_pts}
       ) do
    check_timestamp_offset = fn {_pad, %PadState{timestamp_offset: timestamp_offset}} ->
      timestamp_offset <= buffer_pts
    end

    {pads_frames, new_state} =
      pads_states
      |> Map.to_list()
      |> Enum.filter(check_timestamp_offset)
      |> Enum.reduce(
        {%{}, state},
        fn {pad, %PadState{events_queue: events_queue}}, {pads_frames, state} ->
          case pop_pad_events(pad, events_queue, state) do
            {{:frame, _frame_pts, frame_data}, state} ->
              {Map.put(pads_frames, pad, frame_data), state}

            {:end_of_stream, state} ->
              {pads_frames, state}
          end
        end
      )
      |> then(fn {pads_frames, state} ->
        {pads_frames, %State{state | previous_interval_end_pts: next_interval_end(state)}}
      end)

    stream_format_action =
      if new_state.current_output_format != state.current_output_format do
        [stream_format: {:compositor_core, new_state.current_output_format}]
      else
        []
      end

    scene_action =
      if new_state.current_scene != state.current_scene do
        [notify_child: {:compositor, {:update_scene, new_state.current_scene}}]
      else
        []
      end

    buffer_action = [
      buffer: {:compositor_core, %Buffer{payload: pads_frames, pts: buffer_pts, dts: buffer_pts}}
    ]

    {stream_format_action ++ scene_action ++ buffer_action, new_state}
  end

  @spec pop_pad_events(Pad.ref_t(), list(PadState.pad_event()), State.t()) ::
          {PadState.frame_event() | PadState.end_of_stream_event(), State.t()}
  defp pop_pad_events(pad, [event | events_tail], state) do
    state = Bunch.Struct.put_in(state, [:pads_states, pad, :events_queue], events_tail)

    case event do
      {:frame, _pts, _frame_data} = frame_event ->
        {frame_event, state}

      :end_of_stream ->
        state =
          state
          |> MockCallbacks.remove_video(pad)
          |> Bunch.Struct.delete_in([:current_output_format, :pads_formats, pad])
          |> Bunch.Struct.delete_in([:pads_states, pad])

        {:end_of_stream, state}

      {:pad_added, pad_options} ->
        state = MockCallbacks.add_video(state, pad, pad_options)
        pop_pad_events(pad, events_tail, state)

      {:stream_format, stream_format} ->
        state =
          Bunch.Struct.put_in(state, [:current_output_format, :pads_formats, pad], stream_format)

        pop_pad_events(pad, events_tail, state)
    end
  end
end
