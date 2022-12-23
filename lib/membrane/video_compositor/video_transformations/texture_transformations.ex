defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations do
  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.{CornersRounding, Cropping}

  @type t :: CornersRounding.t() | Cropping.t()
end
