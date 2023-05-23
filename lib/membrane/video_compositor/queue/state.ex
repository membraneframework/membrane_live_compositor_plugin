defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc """
  Responsible for keeping tract of queue state.
  """

  alias Bunch
  alias Membrane.{Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.Offline.State, as: OfflineStrategyState
  alias Membrane.VideoCompositor.Queue.State.PadState
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @enforce_keys [:output_framerate]
  defstruct @enforce_keys ++
              [
                pads_states: %{},
                next_buffer_pts: 0,
                current_output_format: %CompositorCoreFormat{pads_formats: %{}},
                current_scene: Scene.empty(),
                scene_update_events: [],
                most_recent_frame_pts: 0,
                custom_strategy_state: OfflineStrategyState.empty()
              ]

  @type pads_states :: %{Pad.ref_t() => PadState.t()}

  @type scene_update_event :: {:update_scene, pts :: Time.non_neg_t(), scene :: Scene.t()}

  @type strategy_state :: OfflineStrategyState.t()

  @type t :: %__MODULE__{
          output_framerate: RawVideo.framerate_t(),
          pads_states: pads_states(),
          next_buffer_pts: Time.non_neg_t(),
          current_output_format: CompositorCoreFormat.t(),
          current_scene: Scene.t(),
          scene_update_events: list(scene_update_event()),
          most_recent_frame_pts: Time.non_neg_t(),
          custom_strategy_state: strategy_state()
        }

  defmodule MockCallbacks do
    @moduledoc """
    MockCallback system for updating the scene with pad events.

    Using separate module and functions for this might currently seem like overkill,
    but this should be easier to adapt to new compositor scene API and callbacks systems.
    """

    alias Membrane.VideoCompositor.Queue.State
    alias Membrane.VideoCompositor.Scene.VideoConfig

    @spec add_video(State.t(), Pad.ref_t(), %{:video_config => VideoConfig.t()}) :: State.t()
    def add_video(state, added_pad, %{video_config: video_config}) do
      Bunch.Struct.put_in(state, [:current_scene, :videos_configs, added_pad], video_config)
    end

    @spec remove_video(State.t(), Pad.ref_t()) :: State.t()
    def remove_video(state, removed_pad) do
      Bunch.Struct.delete_in(state, [:current_scene, :videos_configs, removed_pad])
    end
  end
end
