defmodule Membrane.VideoCompositor.Canvas do
  @moduledoc false

  alias Membrane.VideoCompositor.Object
  alias __MODULE__.Manipulation

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [manipulations: []]

  @type t :: %__MODULE__{
          input: Object.input_t(),
          manipulations: [Manipulation.name_t()]
        }
end
