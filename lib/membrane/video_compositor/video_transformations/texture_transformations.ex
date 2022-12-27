defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations do
  @moduledoc """
  Defines
  """

  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.{
    CornersRounding,
    Cropping
  }

  @typedoc """
  Describes all texture transformations applied to video.
  Texture transformations can change resolution of frame.
  Applying texture transformations may change size of
  video on the output frame (e.x. adding border to video
  will make video larger).
  As a developer adding new type of texture transformation,
  you must create new struct module type and add it to
  this type definition.
  """
  @type t :: CornersRounding.t() | Cropping.t()
end
