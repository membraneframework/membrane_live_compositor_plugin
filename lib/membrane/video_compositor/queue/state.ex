defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc false

  alias Bunch
  alias Membrane.{Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.State.PadState
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @enforce_keys [:target_fps]
  defstruct @enforce_keys ++
              [
                pads_states: %{},
                previous_interval_end_pts: 0,
                current_output_format: %CompositorCoreFormat{pads_formats: %{}},
                current_scene: Scene.empty(),
                scene_update_events: [],
                most_recent_frame_pts: 0
              ]

  @type pads_states :: %{Pad.ref_t() => PadState.t()}
  @type notify_compositor_scene :: [notify_child: {:compositor_core, {:update_scene, Scene.t()}}]

  @type scene_update_event :: {:update_scene, pts :: Time.non_neg_t(), scene :: Scene.t()}
  @type t :: %__MODULE__{
          target_fps: RawVideo.framerate_t(),
          pads_states: pads_states(),
          previous_interval_end_pts: nil | Time.non_neg_t(),
          current_output_format: CompositorCoreFormat.t(),
          current_scene: Scene.t(),
          scene_update_events: list(scene_update_event()),
          most_recent_frame_pts: Time.non_neg_t()
        }

  defmodule MockCallbacks do
    @moduledoc false
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
