defmodule Membrane.VideoCompositor.Scene.Object.Texture do
  @moduledoc """
  Texture takes a frame received from Video Compositor objects,
  applies all transformations and can be passed as an input
  to other objects.

  Basically wraps multiple single-input, single-output processing graph nodes.
  """

  alias Membrane.VideoCompositor.Scene.{Object, Resolution, Transformation}

  defmodule RustlerFriendly do
    @moduledoc false

    alias Membrane.VideoCompositor.Scene.{Object, Resolution, Transformation}

    @type output_resolution ::
            {:resolution, Resolution.t()} | {:name, Object.name()} | :transformed_input_resolution

    @enforce_keys [:input]
    defstruct @enforce_keys ++ [transformations: [], resolution: :transformed_input_resolution]

    @type t :: %__MODULE__{
            input: Object.name(),
            transformations: [Transformation.rust_representation()],
            resolution: output_resolution()
          }
  end

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
          input: Object.input(),
          transformations: [Transformation.definition()],
          resolution: output_resolution()
        }

  @spec encode(t()) :: RustlerFriendly.t()
  def encode(texture) do
    encoded_transformations =
      texture.transformations
      |> Enum.map(fn transformation ->
        case transformation do
          %module{} -> module.encode(transformation)
          module -> module.encode(transformation)
        end
      end)

    encoded_resolution = Object.encode_output_resolution(texture.resolution)

    %RustlerFriendly{
      input: texture.input,
      transformations: encoded_transformations,
      resolution: encoded_resolution
    }
  end
end
