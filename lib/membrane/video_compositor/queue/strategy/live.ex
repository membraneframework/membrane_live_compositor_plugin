defmodule Membrane.VideoCompositor.Queue.Strategy.Live do
  @moduledoc false
  # Module responsible for frames / events enqueueing accordingly to live composing strategy

  use Membrane.Filter

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.State
  alias Membrane.VideoCompositor.Queue.State.{HandlerState, PadState}
  alias Membrane.VideoCompositor.Queue.Strategy.Live.State, as: LiveState
  alias Membrane.VideoCompositor.QueueingStrategy.Live

  @type latency :: Membrane.Time.non_neg() | :wait_for_start_event

  @type start_timer_message ::
          :start_composing | {:start_composing, delay :: Membrane.Time.non_neg()}

  def_options vc_init_options: [
                spec: VideoCompositor.init_options()
              ],
              latency: [
                spec: latency()
              ]

  def_input_pad :input,
    accepted_format: %RawVideo{pixel_format: :I420},
    availability: :on_request,
    demand_mode: :auto,
    options: [
      timestamp_offset: [
        spec: Membrane.Time.non_neg(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      metadata: [
        spec: VideoCompositor.init_metadata()
      ]
    ]

  def_output_pad :output,
    accepted_format: %CompositorCoreFormat{},
    availability: :always,
    demand_mode: :auto

  @impl true
  def handle_init(_ctx, %{
        vc_init_options:
          vc_init_options = %VideoCompositor{
            output_stream_format: %RawVideo{framerate: framerate},
            queuing_strategy: %Live{latency: latency, eos_strategy: eos_strategy}
          }
      }) do
    {[],
     %State{
       output_framerate: framerate,
       custom_strategy_state: %LiveState{
         latency: latency,
         eos_strategy: eos_strategy
       },
       handler: HandlerState.new(vc_init_options)
     }}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[stream_format: {:output, %CompositorCoreFormat{pad_formats: %{}}}], state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    state =
      state
      |> Bunch.Struct.put_in([:pads_states, pad], PadState.new(context.options))
      |> Bunch.Struct.put_in([:custom_strategy_state, :started_playing?], true)

    {[], state}
  end

  @impl true
  def handle_start_of_stream(_pad, _ctx, state = %State{}) do
    if state.custom_strategy_state.timer_started? do
      {[], state}
    else
      state = Bunch.Struct.put_in(state, [:custom_strategy_state, :timer_started?], true)

      case state.custom_strategy_state.latency do
        :wait_for_start_event ->
          {[], state}

        latency_time ->
          {[start_timer: {:initializer, latency_time}], state}
      end
    end
  end

  @impl true
  def handle_stream_format(pad, stream_format, _ctx, state) do
    state = State.register_event(state, {{:stream_format, stream_format}, pad})
    {[], state}
  end

  @impl true
  def handle_end_of_stream(pad, _ctx, state) do
    state = State.register_event(state, {:end_of_stream, pad})
    {[], state}
  end

  @impl true
  def handle_process(pad, buffer, _ctx, state) do
    state = State.register_event(state, {{:frame, buffer.pts, buffer.payload}, pad})
    {[], state}
  end

  @impl true
  def handle_tick(:initializer, _ctx, state) do
    {[stop_timer: :initializer, start_timer: {:buffer_scheduler, get_tick_ratio(state)}], state}
  end

  @impl true
  def handle_tick(
        :buffer_scheduler,
        _ctx,
        initial_state = %State{next_buffer_pts: buffer_pts}
      ) do
    state = drop_eos_pads(initial_state)

    indexes =
      state.pads_states
      |> Enum.map(fn {pad, %PadState{events_queue: events_queue}} ->
        {pad, nearest_frame_index(events_queue, buffer_pts)}
      end)
      |> Enum.reject(fn {_pad, index} -> index == :no_frame end)
      |> Enum.into(%{})

    {pads_frames, new_state} = State.pop_events(state, indexes, true)

    actions = State.get_actions(new_state, initial_state, pads_frames, buffer_pts)

    if send_eos?(new_state) do
      {actions ++ [stop_timer: :buffer_scheduler, end_of_stream: :output], new_state}
    else
      {actions, new_state}
    end
  end

  @impl true
  def handle_parent_notification(:start_composing, _ctx, state) do
    check_timer_started(state)
    state = Bunch.Struct.put_in(state, [:custom_strategy_state, :timer_started?], true)
    {[start_timer: {:buffer_scheduler, get_tick_ratio(state)}], state}
  end

  @impl true
  def handle_parent_notification({:start_composing, delay}, _ctx, state) do
    check_timer_started(state)
    state = Bunch.Struct.put_in(state, [:custom_strategy_state, :timer_started?], true)
    {[start_timer: {:initializer, delay}], state}
  end

  @impl true
  def handle_parent_notification(:schedule_eos, _ctx, state) do
    if Bunch.Access.get_in(state, [:custom_strategy_state, :eos_strategy]) == :all_inputs_eos do
      raise """
      The ":schedule_eos" message is only handled if ":schedule_eos" was selected as "eos_strategy".
      See
        - Membrane.VideoCompositor.QueueingStrategy.Live.t() and
        - Membrane.VideoCompositor.QueueingStrategy.Live.eos_strategy()
      for more information.
      """
    else
      state = Bunch.Struct.put_in(state, [:custom_strategy_state, :eos_scheduled?], true)
      {[], state}
    end
  end

  @impl true
  def handle_parent_notification(msg, _ctx, state) do
    state = State.register_event(state, {:message, msg})
    {[], state}
  end

  @spec nearest_frame_index([PadState.pad_event()], Membrane.Time.non_neg()) ::
          non_neg_integer() | :no_frame
  defp nearest_frame_index(events_queue, tick_pts) do
    events_queue
    |> Enum.with_index()
    |> Enum.reduce_while(
      {:no_frame, :no_frame},
      fn {event, index}, {best_diff, best_diff_index} ->
        case event do
          {:frame, frame_pts, _frame_data}
          when best_diff == :no_frame or best_diff > abs(frame_pts - tick_pts) ->
            {:cont, {abs(frame_pts - tick_pts), index}}

          {:frame, _frame_pts, _frame_data} ->
            {:halt, {best_diff, best_diff_index}}

          _else ->
            {:cont, {best_diff, best_diff_index}}
        end
      end
    )
    |> then(fn {_best_diff, best_diff_index} -> best_diff_index end)
  end

  defp get_tick_ratio(%State{output_framerate: {output_fps_num, output_fps_den}}) do
    %Ratio{numerator: output_fps_den * Membrane.Time.second(), denominator: output_fps_num}
  end

  defp check_timer_started(state) do
    if state.custom_strategy_state.timer_started? do
      raise "Failed to start timer. Timer already started."
    end
  end

  @spec send_eos?(State.t()) :: boolean()
  defp send_eos?(%State{
         pads_states: pads_states,
         next_buffer_pts: buffer_pts,
         custom_strategy_state: live_state
       }) do
    case live_state do
      %LiveState{started_playing?: false} ->
        false

      %LiveState{eos_strategy: :all_inputs_eos} ->
        all_pads_eos?(pads_states, buffer_pts)

      %LiveState{eos_strategy: :schedule_eos, eos_scheduled?: false} ->
        false

      %LiveState{eos_strategy: :schedule_eos, eos_scheduled?: true} ->
        all_pads_eos?(pads_states, buffer_pts)
    end
  end

  @spec drop_eos_pads(State.t()) :: State.t()
  defp drop_eos_pads(
         state = %State{
           pads_states: pads_states,
           output_format: %CompositorCoreFormat{pad_formats: pad_formats},
           next_buffer_pts: buffer_pts
         }
       ) do
    eos_pads =
      pads_states
      |> Enum.filter(fn {_pad, %PadState{events_queue: events_queue}} ->
        eos_before_pts?(events_queue, buffer_pts)
      end)
      |> Enum.map(fn {pad, _pad_state} -> pad end)

    %State{
      state
      | pads_states: Map.drop(pads_states, eos_pads),
        output_format: %CompositorCoreFormat{pad_formats: Map.drop(pad_formats, eos_pads)}
    }
  end

  @spec all_pads_eos?(%{Membrane.Pad.ref() => PadState.t()}, Membrane.Time.non_neg()) ::
          boolean()
  defp all_pads_eos?(pads_states, buffer_pts) do
    pads_states
    |> Map.values()
    |> Enum.all?(fn %PadState{events_queue: events_queue} ->
      eos_before_pts?(events_queue, buffer_pts)
    end)
  end

  @spec eos_before_pts?(list(PadState.pad_event()), Membrane.Time.non_neg()) :: boolean()
  defp eos_before_pts?(events_queue, buffer_pts) do
    Enum.reduce_while(events_queue, false, fn event, _eos_before_pts? ->
      case event do
        {:frame, pts, _data} when pts > buffer_pts -> {:halt, false}
        :end_of_stream -> {:halt, true}
        _else -> {:cont, false}
      end
    end)
  end
end
