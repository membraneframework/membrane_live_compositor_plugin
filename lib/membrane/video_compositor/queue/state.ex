defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc """
  Responsible for keeping tract of queue state.
  """

  alias Bunch
  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.Element.Action
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

  @spec check_callbacks(t(), t()) :: t()
  def check_callbacks(previous_state, new_state) do
    new_state =
      if previous_state.output_format != new_state.output_format do
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

            state ->
              {new_state.scene, state}
          end

        %__MODULE__{
          new_state
          | handler: {handler_state, handler},
            scene: scene
        }
      end

    new_state
  end

  @spec actions(t(), t(), %{Pad.ref_t() => binary()}, Time.non_neg_t()) ::
          [Action.stream_format_t() | Action.event_t() | Action.buffer_t()]
  def actions(previous_state, new_state, pad_frames, buffer_pts) do
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
      buffer: {:output, %Buffer{payload: pad_frames, pts: buffer_pts, dts: buffer_pts}}
    ]

    stream_format_action ++ scene_action ++ buffer_action
  end

  @spec update_next_buffer_pts(t()) :: t()
  def update_next_buffer_pts(
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

  @spec get_inputs(t()) :: Inputs.t()
  defp get_inputs(%__MODULE__{
         output_format: %CompositorCoreFormat{pad_formats: pad_formats},
         pads_states: pads_states
       }) do
    pad_formats
    |> Enum.map(fn {pad, pad_format} ->
      alias Membrane.VideoCompositor.Queue.State.PadState
      %PadState{metadata: metadata} = Map.fetch!(pads_states, pad)
      {pad, %InputProperties{stream_format: pad_format, metadata: metadata}}
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
