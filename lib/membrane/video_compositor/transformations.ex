defmodule Membrane.VideoCompositor.Transformations do
  @moduledoc """
  Describes all transformations applied to video.
  Transformations can change resolution of frame.
  Applying transformations may change size of
  video on the output frame (e.x. adding border to video
  will make video larger).
  As a contributor adding a new type of transformation,
  you must create new struct module type and add it to
  this type definition.
  """

  alias Membrane.VideoCompositor.Transformations.{
    CornersRounding,
    Cropping
  }

  @type t :: CornersRounding.t() | Cropping.t()
end
