defmodule Membrane.VideoCompositor.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.{Canvas, Compound, Texture}
  alias Membrane.VideoCompositor.Canvas.Manipulation
  alias Membrane.VideoCompositor.Texture.Transformation

  @typedoc """
  An Object is a renderable entity within Video Compositor.
  """
  @type t :: Canvas.t() | Compound.t() | Texture.t()

  @type name_t :: any()
  @type input_t :: t() | Pad.name_t()

  defmodule __MODULE__.Alternation do
    @moduledoc """
    An alteration is a common name of all modifications of single-input objects.
    """

    @type definition_t :: Manipulation.definition_t() | Transformation.definition_t()
    @type name_t :: Manipulation.name_t() | Transformation.name_t()
  end
end
