defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Grid do
  @moduledoc false

  @enforce_keys [:videos_count]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          videos_count: non_neg_integer()
        }
end
