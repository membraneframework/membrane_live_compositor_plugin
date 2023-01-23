defmodule Membrane.VideoCompositor.Compound.BaseSize do
  @moduledoc false

  @enforce_keys [:height, :width]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          height: integer(),
          width: integer()
        }
end
