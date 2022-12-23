defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping do

  @type t :: %__MODULE__{
    top_left_corner: {float(), float()},
    crop_size: {float(), float()},
  }

  @enforce_keys [:top_left_corner, :crop_size]
  defstruct @enforce_keys
end
