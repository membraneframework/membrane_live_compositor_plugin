defmodule Membrane.VideoCompositor.Handler.CallbackCtx.Info do
  @moduledoc false

  alias Membrane.Time
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Handler.CallbackCtx

  @enforce_keys [:input_pads, :scenes_queue, :current_scene, :earliest_start]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          input_pads: CallbackCtx.intput_pads(),
          scenes_queue: CallbackCtx.scenes_queue(),
          current_scene: Scene.t(),
          earliest_start: Time.t()
        }
end
