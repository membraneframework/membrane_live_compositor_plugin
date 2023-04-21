defmodule Membrane.VideoCompositor.TextureTransformations do
  @moduledoc """
  Describes all texture transformations applied to video.
  Texture transformations can change resolution of frame.
  Applying texture transformations may change size of
  video on the output frame (e.x. adding border to video
  will make video larger).
  As a contributor adding a new type of texture transformation,
  you must create new struct module type and add it to
  this type definition.
  """

  alias Membrane.VideoCompositor.TextureTransformations.{
    CornersRounding,
    Cropping
  }

  @type t :: CornersRounding.t() | Cropping.t()
end
