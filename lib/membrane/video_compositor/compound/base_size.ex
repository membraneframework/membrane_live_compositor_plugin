defmodule Membrane.VideoCompositor.Compound.BaseSize do
  @moduledoc """
  A struct describing the base video size.
  """

  @enforce_keys [:height, :width]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          height: integer(),
          width: integer()
        }
end
