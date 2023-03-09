defmodule Membrane.VideoCompositor.Scene.Texture do
  @moduledoc """
  Texture take frame received from Video Compositor objects,
  apply all transformations and can be passed as an input
  for other objects.
  """

  alias Membrane.VideoCompositor.Scene.Object
  alias Membrane.VideoCompositor.Scene.Transformation

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [transformations: [], resolution: :transformed_input_resolution]

  @typedoc """
  Defines texture object, that takes frames from input Object (rendered frame),
  applies all transformations sequentially and can be passed as an input for other
  objects.
  """
  @type t :: %__MODULE__{
          input: Object.name(),
          transformations: [Transformation.definition()],
          resolution: Object.object_output_resolution() | :transformed_input_resolution
        }
end
