defmodule Membrane.VideoCompositor.Resolution do
  @moduledoc """
  Resolution of input stream.
  """

  @enforce_keys [:width, :height]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer()
        }
end
