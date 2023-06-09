defmodule Membrane.VideoCompositor.Handler.CallbackContext do
  @moduledoc """
  Structure representing a common part of the context
  for all of the callbacks. All fields contain state of VC
  before event invoking callback.
  """

  alias Membrane.VideoCompositor.Handler.InputsDescription
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.TemporalScene

  @enforce_keys [:scene, :inputs_description, :next_buffer_pts]
  defstruct @enforce_keys

  @typedoc """
  Contains state of VC before event invoking of callback.
  """
  @type t :: %__MODULE__{
          scene: Scene.t() | TemporalScene.t(),
          inputs_description: InputsDescription.t(),
          next_buffer_pts: Membrane.Time.non_neg_t()
        }
end
