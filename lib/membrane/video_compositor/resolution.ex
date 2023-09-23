defmodule Membrane.VideoCompositor.Resolution do
  @moduledoc false

  defstruct [:width, :height]

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer()
        }
end
