defmodule Membrane.VideoCompositor.Mock.Transformations.CornersRounding do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Scene.Transformation

  @enforce_keys [:border_radius]
  defstruct @enforce_keys

  @typedoc """
  Describe corners rounding texture transformation parameter.

  Corner rounding transformation can be imagined as placing four circles with a specified radius
  adjoining to frame borders, placed inside the frame and making space between the circle edge and
  the nearest frame corner transparent.
  ## Values
  - border_radius: non-negative integer representing the radius of the circle "cutting"
  frame corner part.
  """
  @type t :: %__MODULE__{
          border_radius: non_neg_integer()
        }

  @impl true
  def encode(_corners_rounding) do
    0
  end
end
