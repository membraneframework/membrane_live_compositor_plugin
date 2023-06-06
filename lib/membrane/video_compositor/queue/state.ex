defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc """
  Responsible for keeping tract of queue state.
  """

  alias Bunch
  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.Element.Action
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.Offline.State, as: OfflineStrategyState
  alias Membrane.VideoCompositor.Queue.State.PadState
  alias Membrane.VideoCompositor.{Scene, SceneChangeEvent}
  alias Membrane.VideoCompositor.VideoConfig
  @enforce_keys [:output_framerate, :custom_strategy_state]
  defstruct @enforce_keys ++
              [
                pads_states: %{},
                next_buffer_pts: 0,
                output_format: %CompositorCoreFormat{pad_formats: %{}},
                scene: Scene.empty(),
                scene_update_events: [],
                most_recent_frame_pts: 0
              ]

  @type pads_states :: %{Pad.ref_t() => PadState.t()}

  @type scene_update_event :: {:update_scene, pts :: Time.non_neg_t(), scene :: Scene.t()}

  @type strategy_state :: OfflineStrategyState.t()

  @type t :: %__MODULE__{
          output_framerate: RawVideo.framerate_t(),
          pads_states: pads_states(),
          next_buffer_pts: Time.non_neg_t(),
          output_format: CompositorCoreFormat.t(),
          scene: Scene.t(),
          scene_update_events: list(scene_update_event()),
          most_recent_frame_pts: Time.non_neg_t(),
          custom_strategy_state: strategy_state()
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


  @spec actions(t(), t(), %{Pad.ref_t() => binary()}, Time.non_neg_t()) ::
          [Action.stream_format_t() | Action.event_t() | Action.buffer_t()]
  def actions(initial_state, new_state, pad_frames, buffer_pts) do
    stream_format_action =
      if new_state.output_format != initial_state.output_format do
        [stream_format: {:output, new_state.output_format}]
      else
        []
      end

    scene_action =
      if new_state.scene != initial_state.scene do
        [event: {:output, %SceneChangeEvent{new_scene: new_state.scene}}]
      else
        []
      end

    buffer_action = [
      buffer: {:output, %Buffer{payload: pad_frames, pts: buffer_pts, dts: buffer_pts}}
    ]

    stream_format_action ++ scene_action ++ buffer_action
  end


  defmodule MockCallbacks do
    @moduledoc """
    MockCallback system for updating the scene with pad events.

    Using separate module and functions for this might currently seem like overkill,
    but this should be easier to adapt to new compositor scene API and callbacks systems.
    """

    alias Membrane.VideoCompositor.Queue.State
    alias Membrane.VideoCompositor.VideoConfig

    @spec add_video(State.t(), Pad.ref_t(), %{:video_config => VideoConfig.t()}) :: State.t()
    def add_video(state, added_pad, %{video_config: video_config}) do
      Bunch.Struct.put_in(state, [:scene, :video_configs, added_pad], video_config)
    end

    @spec remove_video(State.t(), Pad.ref_t()) :: State.t()
    def remove_video(state, removed_pad) do
      Bunch.Struct.delete_in(state, [:scene, :video_configs, removed_pad])
    end
  end
end
