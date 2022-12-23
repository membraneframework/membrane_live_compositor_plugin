defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding do

  @type t :: %__MODULE__{
    corner_rounding_radius: float()
  }

  @enforce_keys [:corner_rounding_radius]
  defstruct @enforce_keys
end
