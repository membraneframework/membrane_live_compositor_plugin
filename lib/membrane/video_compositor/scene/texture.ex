defmodule Membrane.VideoCompositor.Scene.Texture do
  @moduledoc """
  Texture takes frame received from Video Compositor objects,
  apply all transformations and can be passed as an input
  for other objects.
  """

  alias Membrane.VideoCompositor.Scene.Object
  alias Membrane.VideoCompositor.Scene.Resolution
  alias Membrane.VideoCompositor.Scene.TransformationSpec

  @enforce_keys [:input, :transformations]
  defstruct @enforce_keys ++ [resolution: :transformed_input_resolution]

  @typedoc """
  Defines texture object, that takes frames from input Object (rendered frame),
  apply all transformations sequentially and can be passed as an input for other
  objects. Resolution of output frame is
  """
  @type t :: %__MODULE__{
          input: Object.name_t(),
          transformations: [TransformationSpec.definition_t()],
          resolution: Resolution.t() | :transformed_input_resolution
        }
end
