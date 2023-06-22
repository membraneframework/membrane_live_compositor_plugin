defmodule Membrane.VideoCompositor.Queue.Live do
  @moduledoc false

  use Membrane.Filter

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.Live.State, as: LiveState
  alias Membrane.VideoCompositor.Queue.State
  alias Membrane.VideoCompositor.Queue.State.{HandlerState, PadState}

  @type latency :: Membrane.Time.non_neg_t() | :wait_for_start_event

  @type start_timer_message :: :start_timer | {:start_timer, delay :: Membrane.Time.non_neg_t()}

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
        spec: Membrane.Time.non_neg_t(),
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
  def handle_init(_ctx, options) do
    {[],
     %State{
       output_framerate: options.vc_init_options.output_stream_format.framerate,
       custom_strategy_state: %LiveState{
         latency: options.latency
       },
       handler: HandlerState.new(options.vc_init_options)
     }}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    state = Bunch.Struct.put_in(state, [:pads_states, pad], PadState.new(context.options))

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
    state = State.put_event(state, {{:stream_format, stream_format}, pad})
    {[], state}
  end

  @impl true
  def handle_end_of_stream(pad, _ctx, state) do
    state = State.put_event(state, {:end_of_stream, pad})
    {[], state}
  end

  @impl true
  def handle_process(pad, buffer, _ctx, state) do
    state = State.put_event(state, {{:frame, buffer.pts, buffer.payload}, pad})
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

    if all_pads_eos?(new_state) do
      {actions ++ [stop_timer: :buffer_scheduler, end_of_stream: :output], new_state}
    else
      {actions, new_state}
    end
  end

  @impl true
  def handle_parent_notification(:start_timer, _ctx, state) do
    check_timer_started(state)
    {[start_timer: {:buffer_scheduler, get_tick_ratio(state)}], state}
  end

  @impl true
  def handle_parent_notification({:start_timer, delay}, _ctx, state) do
    check_timer_started(state)
    {[start_timer: {:initializer, delay}], state}
  end

  @impl true
  def handle_parent_notification(msg, _ctx, state) do
    state = State.put_event(state, {:message, msg})
    {[], state}
  end

  @spec nearest_frame_index([PadState.pad_event()], Membrane.Time.non_neg_t()) ::
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
    %Ratio{numerator: output_fps_num, denominator: output_fps_den}
  end

  defp check_timer_started(state) do
    if state.custom_strategy_state.timer_started? do
      raise "Failed to start timer. Timer already started."
    end
  end

  @spec all_pads_eos?(State.t()) :: boolean()
  defp all_pads_eos?(%State{pads_states: pads_states}) do
    pads_states
    |> Map.values()
    |> Enum.any?(fn %PadState{events_queue: events_queue} ->
      Enum.at(events_queue, -1) == :end_of_stream
    end)
  end

  @spec drop_eos_pads(State.t()) :: State.t()
  defp drop_eos_pads(state = %State{pads_states: pads_states, next_buffer_pts: buffer_pts}) do
    dropped_pads_states =
      pads_states
      |> Enum.reject(fn {_pad, %PadState{events_queue: events_queue}} ->
        eos_before_pts?(events_queue, buffer_pts)
      end)
      |> Enum.into(%{})

    %State{state | pads_states: dropped_pads_states}
  end

  @spec eos_before_pts?(list(PadState.pad_event()), Membrane.Time.non_neg_t()) :: boolean()
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
