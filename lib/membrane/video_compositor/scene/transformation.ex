defmodule Membrane.VideoCompositor.Scene.Transformation do
  @moduledoc """
  Behaviour representing single input, single output transformations of objects.
  Transformations are single frame input - single frame output objects.
  Transformations can change frame resolution. Cropping, CornersRounding, ColorFiler,
  RollToBall etc. can be implemented as transformations.
  """

  @type definition_t :: struct() | module()
  @type name_t :: tuple() | atom()
end
