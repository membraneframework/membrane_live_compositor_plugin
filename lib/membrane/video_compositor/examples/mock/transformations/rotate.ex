defmodule Membrane.VideoCompositor.Examples.Mock.Transformations.Rotate do
  @moduledoc false

  @enforce_keys [:degrees]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          degrees: non_neg_integer()
        }
end
