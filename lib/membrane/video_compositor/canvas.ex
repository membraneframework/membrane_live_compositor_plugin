defmodule Membrane.VideoCompositor.Canvas do
  @moduledoc false

  alias __MODULE__.Manipulation
  alias Membrane.VideoCompositor.Object

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [manipulations: []]

  @type t :: %__MODULE__{
          input: Object.input_t(),
          manipulations: [Manipulation.name_t()]
        }
end
