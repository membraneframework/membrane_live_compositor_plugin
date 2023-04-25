defmodule Membrane.VideoCompositor.Handler.CallbackCtx.Info do
  @moduledoc """
  Structure representing a context that is passed when video compositor
  receives a message that is not recognized as an internal membrane message.
  """

  alias Membrane.Time
  alias Membrane.VideoCompositor.Handler.CallbackCtx
  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:input_pads, :scenes_queue, :current_scene, :earliest_start]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          input_pads: CallbackCtx.intput_pads(),
          scenes_queue: CallbackCtx.scenes_queue(),
          current_scene: Scene.t(),
          earliest_start: Time.t()
        }
end
