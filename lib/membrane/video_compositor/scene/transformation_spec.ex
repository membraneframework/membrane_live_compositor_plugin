defmodule Membrane.VideoCompositor.Scene.TransformationSpec do
  @moduledoc """
  Defines how transformation should look like.
  """

  @typedoc """
  Transformations are single frame input - single frame output objects, that can be
  defied with modules or module structs. Transformations can change frame resolution.
  Cropping, CornersRounding, ColorFiler, RollToBall etc. can be implemented as transformations.
  """
  @type definition_t :: struct() | module()
end
