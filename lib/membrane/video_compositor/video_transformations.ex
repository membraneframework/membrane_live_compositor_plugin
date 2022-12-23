defmodule Membrane.VideoCompositor.VideoTransformations do
  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations

  @type t :: %__MODULE__{
    texture_transformations: list(TextureTransformations.t())
  }

  @enforce_keys [:texture_transformations]
  defstruct @enforce_keys
end
