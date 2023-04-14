defmodule Membrane.VideoCompositor.Scene.Object.Input.Video do
  @moduledoc """
  Structure representing `Video` wrapper for using input
  Membrane Pad of an element as a object in a scene.
  """
  alias Membrane.Pad

  @enforce_keys [:input_pad]
  defstruct @enforce_keys

  @typedoc """
  Defines pad wrapper.
  """
  @type t :: %__MODULE__{
          input_pad: Pad.ref_t()
        }
end
