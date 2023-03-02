defmodule Membrane.VideoCompositor.Scene.Transformation do
  @moduledoc """
  Behaviour representing single input, single output transformations of objects.
  Transformations are single frame input - single frame output objects.
  Transformations can change frame resolution. Cropping, CornersRounding, ColorFiler,
  RollToBall etc. can be implemented as transformations.
  """

  @typedoc """
  Specify how Textures can be defined:
    - By struct - when transformation can be parametrized with different values
    e.g. corners round (parametrized wit border radius), cropping etc. 
    - By module - when there is no reasonable / common use cases of parametrization,
    and identifying transformation without it is enough e.g. RollToBall - transformation
    turning input object / frame / video into ball
  """
  @type definition_t :: struct() | module()
  @type name_t :: tuple() | atom()
end
