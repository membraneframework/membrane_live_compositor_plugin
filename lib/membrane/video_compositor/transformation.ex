defmodule Membrane.VideoCompositor.Transformation do
  @moduledoc """
  Module representing single-input, single-output frames processing graph nodes
  that apply a single effect on the input frame (e.g. crop them or round corners).

  Transformations can change frame resolution. Cropping, CornersRounding, ColorFiler,
  RollToBall, etc. can be implemented as transformations.
  """
  alias Membrane.VideoCompositor.WgpuAdapter

  @typedoc """
  Specify how Transformations can be defined:
    - By struct - when transformation can be parametrized with different values
    e.g. corners round (parametrized with border-radius), cropping, etc.
    - By module - when there are no reasonable / common use cases of parametrization,
    and identifying transformation without it is enough e.g. RollToBall - transformation
    turning input object / frame / video into the ball
  """
  @type definition :: struct() | module()

  @typedoc """
  A module implementing the `Transformation` specification
  """
  @type transformation_module :: module()

  @typedoc """
  A rust representation of the transformation parameters as defined in a scene graph, passed through elixir
  in an opaque way. In other words, those are the parameters that will be passed to the initialized
  transformation.

  Keep in mind the transformation needs to be registered before it's used in a scene graph.
  """
  @opaque encoded_params :: {non_neg_integer(), non_neg_integer()}

  @typedoc """
  This type is an initialized transformation that needs to be transported through elixir to the compositor.
  In other words, this is the *brains* of the transformation, that will receive the parameters specified in
  a scene graph.
  """
  @opaque initialized_transformation :: {non_neg_integer(), non_neg_integer()}

  @doc """
  A callback used for encoding the static layout data into a rust-based representation.
  We don't know yet how exactly this system is going to work, so this is just a placeholder
  for now.
  """
  @callback encode(transformation :: definition()) :: encoded_params()

  @doc """
  This function receives the wgpu context from the compositor and needs to create the initialized
  transformation
  """
  @callback initialize(WgpuAdapter.wgpu_ctx()) :: initialized_transformation()

  @doc false
  # This just cases upon the two possibilities of the definition.
  @spec encode(definition()) :: encoded_params()
  def encode(transformation) do
    case transformation do
      %module{} -> module.encode(transformation)
      module -> module.encode(transformation)
    end
  end
end
