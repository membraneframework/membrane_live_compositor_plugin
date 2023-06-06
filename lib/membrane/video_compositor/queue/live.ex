defmodule Membrane.VideoCompositor.Queue.Live do
  @moduledoc false

  use Membrane.Filter

  alias Membrane.{Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.{CompositorCoreFormat, VideoConfig}
  alias Membrane.VideoCompositor.Queue.Live.State, as: LiveState
  alias Membrane.VideoCompositor.Queue.State
  alias Membrane.VideoCompositor.Queue.State.{MockCallbacks, PadState}

  @type latency :: Time.non_neg_t() | :wait_for_start_event

  def_options output_framerate: [
                spec: RawVideo.framerate_t(),
                description: "Framerate of the output video of the compositor"
              ],
              latency: [
                spec: latency()
              ]

  def_input_pad :input,
    accepted_format: %RawVideo{pixel_format: :I420},
    availability: :on_request,
    options: [
      video_config: [
        spec: VideoConfig.t(),
        description: "Specify how single input video should be transformed"
      ],
      timestamp_offset: [
        spec: Membrane.Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ]
    ]

  def_output_pad :output,
    accepted_format: %CompositorCoreFormat{},
    availability: :always

  @impl true
  def handle_init(_ctx, %{output_framerate: output_framerate, latency: latency}) do
    {[],
     %State{
       output_framerate: output_framerate,
       custom_strategy_state: %LiveState{latency: latency}
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
      state = Bunch.Struct.put_in(state, [:custom_strategy_state, :timer_started], true)

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
  def handle_process(pad, buffer, _ctx, state) do
    state = State.put_event(state, {{:frame, buffer.pts, buffer.payload}, pad})
    {[], state}
  end

  @impl true
  @spec handle_tick(:buffer_scheduler | :initializer, any, any) ::
          {[{:start_timer, {any, any}} | {:stop_timer, :initializer}], any}
  def handle_tick(:initializer, _ctx, state) do
    {output_fps_num, output_fps_den} = state.output_framerate
    buffer_scheduler_tick_ratio = %Ratio{numerator: output_fps_num, denominator: output_fps_den}

    {[stop_timer: :initializer, start_timer: {:buffer_scheduler, buffer_scheduler_tick_ratio}],
     state}
  end

  @impl true
  def handle_tick(
        :buffer_scheduler,
        _ctx,
        initial_state = %State{next_buffer_pts: next_buffer_pts}
      ) do
    {new_state, pad_frames} = pop_pads_events(initial_state)

    actions = State.actions(initial_state, new_state, pad_frames, next_buffer_pts)
    # calculate new buffer pts here

    {actions, new_state}
  end

  @spec pop_pads_events(State.t()) ::
          {updated_state :: State.t(), pad_frames :: %{Pad.ref_t() => binary()}}
  defp pop_pads_events(state = %State{pads_states: pads_states, next_buffer_pts: next_buffer_pts}) do
    pads_states
    |> Map.keys()
    |> Enum.reduce(
      {state, %{}},
      fn pad, {state, pad_frames} ->
        case pop_pad_events(state, pad, next_buffer_pts) do
          {state, :no_frame} ->
            {state, pad_frames}

          {state, frame} ->
            {state, Map.put(pad_frames, pad, frame)}
        end
      end
    )
  end

  @spec pop_pad_events(State.t(), Pad.ref_t(), Time.non_neg_t()) ::
          {updated_state :: State.t(), binary() | :no_frame}
  defp pop_pad_events(state = %State{}, pad, tick_pts) do
    events_queue = Bunch.Struct.get_in(state, [:pads_states, pad, :events_queue])

    case nearest_frame_index(events_queue, tick_pts) do
      :no_frame ->
        {state, :no_frame}

      index ->
        {events_before_best_frame, tail = [{:frame, _pts, frame_data} | _]} =
          Enum.split(events_queue, index)

        state =
          state
          |> Bunch.Struct.put_in([:pad_states, pad, :events_queue], tail)
          |> handle_events_before_best_frame(pad, events_before_best_frame)

        {state, frame_data}
    end
  end

  @spec nearest_frame_index([PadState.pad_event()], Time.non_neg_t()) ::
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

  defp handle_events_before_best_frame(state, pad, events) do
    Enum.reduce(
      events,
      state,
      fn event, state ->
        case event do
          {:pad_added, pad_options} ->
            MockCallbacks.add_video(state, pad, pad_options)

          :end_of_stream ->
            state
            |> MockCallbacks.remove_video(pad)
            |> Bunch.Struct.delete_in([:output_format, :pad_formats, pad])
            |> Bunch.Struct.delete_in([:pads_states, pad])

          {:stream_format, stream_format} ->
            Bunch.Struct.put_in(state, [:output_format, :pad_formats, pad], stream_format)
        end
      end
    )
  end
end
