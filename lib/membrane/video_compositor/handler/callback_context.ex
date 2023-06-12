defmodule Membrane.VideoCompositor.Handler.CallbackContext do
  @moduledoc """
  Structure representing a common part of the context
  for all of the callbacks. All fields contain state of VC
  before event invoking callback.
  """

  alias Membrane.VideoCompositor.{Handler, Scene}

  @enforce_keys [:scene, :inputs, :next_frame_pts]
  defstruct @enforce_keys

  @typedoc """
  Contains state of VC before event invoking of callback.
  """
  @type t :: %__MODULE__{
          scene: Scene.t() | Handler.temporal_scene(),
          inputs: Handler.inputs(),
          next_frame_pts: Membrane.Time.non_neg_t()
        }
end
