defmodule Membrane.VideoCompositor.Object do
  @moduledoc false

  alias Membrane.Pad
  alias Membrane.VideoCompositor.{Canvas, Compound, Texture}
  alias Membrane.VideoCompositor.Canvas.Manipulation
  alias Membrane.VideoCompositor.Texture.Transformation

  @type t :: Canvas.t() | Compound.t() | Texture.t()
  @type name_t :: any()

  @type input_t :: t() | Pad.name_t()

  defmodule __MODULE__.Alternation do
    @type definition_t :: Manipulation.definition_t() | Transformation.definition_t()
    @type name_t :: Manipulation.name_t() | Transformation.name_t()
  end
end
