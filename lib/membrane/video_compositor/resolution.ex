defmodule Membrane.VideoCompositor.Resolution do
  @moduledoc """
  Simple resolution definition.
  """

  @enforce_keys [:width, :height]
  defstruct @enforce_keys

  @typedoc """
  Defines frame / video resolution.
  """
  @type t ::
          %__MODULE__{
            width: non_neg_integer(),
            height: non_neg_integer()
          }
end
