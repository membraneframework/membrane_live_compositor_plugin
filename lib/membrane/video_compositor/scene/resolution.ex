defmodule Membrane.VideoCompositor.Scene.Resolution do
  @moduledoc false

  @enforce_keys [:width, :height]
  defstruct @enforce_keys

  @type t ::
          %__MODULE__{
            width: non_neg_integer(),
            height: non_neg_integer()
          }
end
