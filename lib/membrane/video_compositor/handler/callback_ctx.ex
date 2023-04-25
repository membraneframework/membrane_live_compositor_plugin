defmodule Membrane.VideoCompositor.Handler.CallbackCtx do
  @moduledoc """
  Structure representing a common part of the context
  for all of the callbacks.
  """
  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:input_pads, :scenes_queue, :current_scene]
  defstruct @enforce_keys

  @type intput_pads :: list(Membrane.Pad.ref_t())

  @type start_scene_timestamp :: Membrane.Time.t()
  @type scenes_queue :: list({Scene.t(), start_scene_timestamp()})

  @type t :: %__MODULE__{
          input_pads: intput_pads(),
          scenes_queue: scenes_queue(),
          current_scene: Scene.t()
        }
end
