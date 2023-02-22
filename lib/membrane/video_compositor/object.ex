defmodule Membrane.VideoCompositor.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.{Canvas, Compound, Texture}

  @typedoc """
  An Object is a renderable entity within Video Compositor.
  """
  @type t :: Canvas.t() | Compound.t() | Texture.t()

  @type name_t :: tuple() | atom()
  @type input_t :: t() | Pad.name_t()

  defmodule __MODULE__.SimpleAlternation do
    @moduledoc """
    A simple alteration is a common name of all modifications of single-input objects.
    """

    @type definition_t ::
            Canvas.Transformation.definition_t() | Texture.Transformation.definition_t()
    @type name_t :: Canvas.Transformation.name_t() | Texture.Transformation.name_t()
  end
end
