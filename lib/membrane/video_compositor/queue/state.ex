defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc false
  # Responsible for keeping tract of queue state.

  alias Bunch
  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.Element.Action
  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.{CompositorCoreFormat, Scene, SceneChangeEvent}
  alias Membrane.VideoCompositor.Queue.Offline.State, as: OfflineStrategyState
  alias Membrane.VideoCompositor.Queue.State.{HandlerState, PadState}

  @enforce_keys [:output_framerate, :custom_strategy_state, :handler]
  defstruct @enforce_keys ++
              [
                pads_states: %{},
                next_buffer_pts: 0,
                next_buffer_number: 1,
                output_format: %CompositorCoreFormat{pad_formats: %{}},
                scene: Scene.empty(),
                user_messages: []
              ]

  @type pads_states :: %{Pad.ref_t() => PadState.t()}

  @type strategy_state :: OfflineStrategyState.t()

  @type t :: %__MODULE__{
          output_framerate: RawVideo.framerate_t(),
          custom_strategy_state: strategy_state(),
          handler: HandlerState.t(),
          pads_states: pads_states(),
          next_buffer_pts: Time.non_neg_t(),
          output_format: CompositorCoreFormat.t(),
          scene: Scene.t(),
          user_messages: list(any())
        }

  @spec register_pad(t(), Pad.ref_t(), VideoCompositor.input_pad_options()) :: t()
  def register_pad(state, pad_ref, pad_options) do
    Bunch.Struct.put_in(state, [:pads_states, pad_ref], PadState.new(pad_options))
  end

  @spec register_buffer(t(), Buffer.t(), Pad.ref_t()) :: t()
  def register_buffer(state, buffer, pad) do
    frame_pts = buffer.pts + Bunch.Struct.get_in(state, [:pads_states, pad, :timestamp_offset])

    Bunch.Struct.update_in(
      state,
      [:pads_states, pad, :events_queue],
      &(&1 ++ [{:frame, frame_pts, buffer.payload}])
    )
  end

  @spec register_event(t(), {PadState.pad_event(), Pad.ref_t()} | {:message, msg :: any()}) :: t()
  def register_event(state, event) do
    case event do
      {:message, msg} ->
        Map.update!(state, :user_messages, &(&1 ++ [msg]))

      {pad_event, pad_ref} ->
        Bunch.Struct.update_in(
          state,
          [:pads_states, pad_ref, :events_queue],
          &(&1 ++ [pad_event])
        )
    end
  end

  @spec pop_events(t(), %{Pad.ref_t() => non_neg_integer()}, boolean()) ::
          {pads_frames :: %{Pad.ref_t() => binary()}, updated_state :: t()}
  def pop_events(state, frame_indexes, keep_frame?) do
    {pads_frames, state} =
      frame_indexes
      |> Enum.reduce(
        {%{}, state},
        fn {pad, index}, {pads_frames, state} ->
          {events_before_frame, tail = [{:frame, _pts, frame_data} | events_after_frame]} =
            state
            |> Bunch.Struct.get_in([:pads_states, pad, :events_queue])
            |> Enum.split(index)

          updated_events_queue = if keep_frame?, do: tail, else: events_after_frame

          state =
            state
            |> Bunch.Struct.put_in([:pads_states, pad, :events_queue], updated_events_queue)
            |> handle_events_before_frame(pad, events_before_frame)

          {Map.put(pads_frames, pad, frame_data), state}
        end
      )

    state =
      state
      |> HandlerState.check_callbacks(state)
      |> update_next_buffer_pts()

    {pads_frames, state}
  end

  @spec handle_events_before_frame(t(), Pad.ref_t(), [PadState.pad_event()]) :: t()
  defp handle_events_before_frame(state, pad, events_before_frame) do
    Enum.reduce(
      events_before_frame,
      state,
      fn event, state ->
        case event do
          {:stream_format, stream_format} ->
            Bunch.Struct.put_in(state, [:output_format, :pad_formats, pad], stream_format)

          _other ->
            state
        end
      end
    )
  end

  @spec get_actions(t(), t(), %{Pad.ref_t() => binary()}, Membrane.Time.non_neg_t()) ::
          [Action.stream_format_t() | Action.event_t() | Action.buffer_t()]
  def get_actions(new_state, previous_state, pads_frames, buffer_pts) do
    new_state = new_state |> HandlerState.check_callbacks(previous_state)

    stream_format_action =
      if new_state.output_format != previous_state.output_format do
        [stream_format: {:output, new_state.output_format}]
      else
        []
      end

    scene_action =
      if new_state.scene != previous_state.scene do
        [event: {:output, %SceneChangeEvent{new_scene: new_state.scene}}]
      else
        []
      end

    buffer_action = [
      buffer: {:output, %Buffer{payload: pads_frames, pts: buffer_pts, dts: buffer_pts}}
    ]

    stream_format_action ++ scene_action ++ buffer_action
  end

  @spec update_next_buffer_pts(t()) :: t()
  defp update_next_buffer_pts(
         state = %__MODULE__{
           output_framerate: {fps_num, fps_den},
           next_buffer_number: next_buffer_number
         }
       ) do
    %__MODULE__{
      state
      | next_buffer_pts: Kernel.ceil(Time.second() * next_buffer_number * fps_den / fps_num),
        next_buffer_number: next_buffer_number + 1
    }
  end
end
