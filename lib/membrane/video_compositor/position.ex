defmodule Membrane.VideoCompositor.Position do
  @moduledoc """
  Position relative to the top right corner of the viewport, in pixels.
  """

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer()
        }

  @enforce_keys [:x, :y]
  defstruct [:x, :y]

  @spec from_tuple({non_neg_integer(), non_neg_integer()}) :: {:ok, __MODULE__.t()}
  def from_tuple({x, y}) do
    {:ok, %__MODULE__{x: x, y: y}}
  end
end
