defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Position do
  @moduledoc """
  A structure representing position of an object in rendered frame.
  """

  @enforce_keys [:top_left_corner, :width, :height]
  defstruct @enforce_keys ++ [z_value: 0.0]

  @typedoc """
  Float in [0, 1] range. Widely used in graphic rendering, to determine distance, color etc.
  """
  @type unit_range :: float()

  @type t :: %__MODULE__{
          top_left_corner: {unit_range(), unit_range()},
          width: unit_range() | :auto,
          height: unit_range() | :auto,
          z_value: unit_range()
        }
end
