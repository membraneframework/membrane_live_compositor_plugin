defmodule Membrane.VideoCompositor.Texture do
  @moduledoc false

  alias Membrane.VideoCompositor.Object
  alias __MODULE__.Transformation

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [transformations: []]

  @type t :: %__MODULE__{
          input: Object.input_t(),
          transformations: [Transformation.name_t()]
        }
end
