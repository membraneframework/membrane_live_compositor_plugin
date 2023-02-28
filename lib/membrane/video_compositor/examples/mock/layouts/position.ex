defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Position do
  @moduledoc false

  @enforce_keys [:top_left_corner, :width, :height, :z_value]
  defstruct @enforce_keys

  @typedoc """
  Float in [0, 1] range. Widely used in graphic rendering, to determine distance, color etc.
  """
  @type unit_range_t :: float()

  @type t :: %__MODULE__{
          top_left_corner: {unit_range_t(), unit_range_t()},
          width: unit_range_t() | :auto,
          height: unit_range_t() | :auto,
          z_value: unit_range_t()
        }
end
