defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc """
  Responsible for keeping tract of queue state.
  """

  alias Bunch
  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.Element.Action
  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Handler.{CallbackContext, Inputs}
  alias Membrane.VideoCompositor.Handler.Inputs.InputProperties
  alias Membrane.VideoCompositor.{CompositorCoreFormat, Handler, Scene, SceneChangeEvent}
  alias Membrane.VideoCompositor.Queue.Offline.State, as: OfflineStrategyState
  alias Membrane.VideoCompositor.Queue.State.PadState

  @enforce_keys [:output_framerate, :custom_strategy_state, :handler]
  defstruct @enforce_keys ++
              [
                pads_states: %{},
                next_buffer_pts: 0,
                next_buffer_number: 1,
                output_format: %CompositorCoreFormat{pad_formats: %{}},
                scene: Scene.empty()
              ]

  @type pads_states :: %{Pad.ref_t() => PadState.t()}

  @type scene_update_event :: {:update_scene, pts :: Time.non_neg_t(), scene :: Scene.t()}

  @type strategy_state :: OfflineStrategyState.t()

  @type t :: %__MODULE__{
          output_framerate: RawVideo.framerate_t(),
          custom_strategy_state: strategy_state(),
          handler: {handler_module :: Handler.t(), state :: Handler.state()},
          pads_states: pads_states(),
          next_buffer_pts: Time.non_neg_t(),
          output_format: CompositorCoreFormat.t(),
          scene: Scene.t()
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

  @spec put_event(t(), scene_update_event() | {PadState.pad_event(), Pad.ref_t()}) :: t()
  def put_event(state, event) do
    case event do
      {:update_scene, _pts, _scene} ->
        Map.update!(state, :scene_update_events, &(&1 ++ [event]))

      {pad_event, pad_ref} ->
        Bunch.Struct.update_in(
          state,
          [:pads_states, pad_ref, :events_queue],
          &(&1 ++ [pad_event])
        )
    end
  end

  @spec pop_events(t(), %{Pad.ref_t() => non_neg_integer()}, boolean()) ::
          {pads_frames :: %{Pad.ref_t() => binary()}, t()}
  def pop_events(state, frame_indexes, keep_frame?) do
    state = drop_oes_pads(state)

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
      |> check_callbacks(state)
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
    new_state = new_state |> check_callbacks(previous_state)

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

  @spec check_callbacks(t(), t()) :: t()
  defp check_callbacks(new_state, previous_state) do
    if previous_state.output_format != new_state.output_format do
      handle_inputs_change(new_state, previous_state)
    else
      new_state
    end
  end

  defp handle_inputs_change(new_state, previous_state) do
    {handler, handler_state} = new_state.handler

    callback_return =
      handler.handle_inputs_change(
        get_inputs(new_state),
        get_callback_context(previous_state),
        handler_state
      )

    {scene, handler_state} =
      case callback_return do
        {scene = %Scene{}, state} ->
          {scene, state}
      end

    %__MODULE__{
      new_state
      | handler: {handler, handler_state},
        scene: scene
    }
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

  @spec drop_oes_pads(t()) :: t()
  def drop_oes_pads(
        state = %__MODULE__{
          pads_states: pads_states,
          output_format: %CompositorCoreFormat{pad_formats: pad_formats}
        }
      ) do
    eos_pads =
      pads_states
      |> Enum.filter(fn {_pad, pad_state} -> is_eos_pad?(pad_state) end)
      |> Enum.map(fn {pad, _pad_state} -> pad end)

    %__MODULE__{
      state
      | pads_states: Map.drop(pads_states, eos_pads),
        output_format: %CompositorCoreFormat{pad_formats: Map.drop(pad_formats, eos_pads)}
    }
  end

  @spec is_eos_pad?(PadState.t()) :: boolean()
  defp is_eos_pad?(%PadState{events_queue: events_queue}) do
    Enum.reduce_while(
      events_queue,
      false,
      fn event, _is_eos? ->
        case PadState.event_type(event) do
          :frame -> {:halt, false}
          :end_of_stream -> {:halt, true}
          _other -> {:cont, false}
        end
      end
    )
  end

  @spec get_inputs(t()) :: Inputs.t()
  defp get_inputs(%__MODULE__{
         output_format: %CompositorCoreFormat{pad_formats: pad_formats},
         pads_states: pads_states
       }) do
    pad_formats
    |> Enum.map(fn {pad, pad_format} ->
      {pad,
       %InputProperties{
         stream_format: pad_format,
         metadata: Bunch.Struct.get_in(pads_states, [pad, :metadata])
       }}
    end)
    |> Enum.into(%{})
  end

  @spec get_callback_context(t()) :: CallbackContext.t()
  defp get_callback_context(state) do
    %CallbackContext{
      scene: state.scene,
      inputs: get_inputs(state),
      next_frame_pts: state.next_buffer_pts
    }
  end
end
