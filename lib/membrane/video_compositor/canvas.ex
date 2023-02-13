defmodule Membrane.VideoCompositor.Canvas do
  @moduledoc """
  Structure representing Canvas objects.
  """

  alias __MODULE__.Transformation
  alias Membrane.VideoCompositor.Object

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [transformations: []]

  @type t :: %__MODULE__{
          input: Object.input_t(),
          transformations: [Transformation.name_t()]
        }
end
