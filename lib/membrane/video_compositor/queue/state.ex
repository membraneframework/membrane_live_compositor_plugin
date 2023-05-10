defmodule Membrane.VideoCompositor.Queue.State do
  @moduledoc false

  alias __MODULE__.PadState
  alias Bunch
  alias Membrane.{Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:target_fps]
  defstruct @enforce_keys ++
              [
                pads_states: %{},
                previous_interval_end_pts: nil,
                current_output_format: %CompositorCoreFormat{pads_formats: %{}},
                current_scene: Scene.empty(),
                most_recent_frame_pts: 0
              ]

  @type pads_states :: %{Pad.ref_t() => PadState.t()}
  @type notify_compositor_scene :: [notify_child: {:compositor_core, {:update_scene, Scene.t()}}]

  @type t :: %__MODULE__{
          target_fps: RawVideo.framerate_t(),
          pads_states: pads_states(),
          previous_interval_end_pts: nil | Time.non_neg_t(),
          current_output_format: CompositorCoreFormat.t(),
          current_scene: Scene.t(),
          most_recent_frame_pts: Time.non_neg_t()
        }
end
