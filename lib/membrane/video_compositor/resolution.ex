defmodule Membrane.VideoCompositor.Resolution do
  @moduledoc """
  Resolution of input stream.
  """

  defstruct [:width, :height]

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer()
        }
end
