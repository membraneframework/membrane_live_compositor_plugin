defmodule Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding do
  @moduledoc false

  @enforce_keys [:border_radius]
  defstruct @enforce_keys

  @typedoc """
  Describe corners rounding texture transformation parameter.
  Corner rounding transformation can be imagined as placing four circles with specified radius
  adjoining to frame borders, placed inside frame and making space between circle edge and
  nearest frame corner transparent.
  ## Values
  - border_radius: non negative integer representing radius of circle "cutting"
  frame corner part.
  """
  @type t :: %__MODULE__{
          border_radius: non_neg_integer()
        }
end
