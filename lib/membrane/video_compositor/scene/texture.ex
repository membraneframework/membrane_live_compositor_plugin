defmodule Membrane.VideoCompositor.Scene.Texture do
  @moduledoc """
  Texture takes a frame received from Video Compositor objects,
  applies all transformations and can be passed as an input
  to other objects.
  """

  alias Membrane.VideoCompositor.Scene.{Object, Resolution, Transformation}

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [transformations: [], resolution: :transformed_input_resolution]

  @typedoc """
  Defines how the output resolution of a texture can be specified.

  Texture resolution can be specified as:
  - plain `Membrane.VideoCompositor.Resolution.t()`
  - resolution of another object
  - transformed resolution of the object input
  (e.g. for corners rounding - same as input,
  for cropping - accordingly smaller than input)
  """
  @type output_resolution :: Resolution.t() | Object.name() | :transformed_input_resolution

  @typedoc """
  Defines texture object, that takes frames from input Object (rendered frame),
  applies all transformations sequentially and can be passed as an input for other
  objects.
  """
  @type t :: %__MODULE__{
          input: Object.name(),
          transformations: [Transformation.definition()],
          resolution: output_resolution()
        }
end
