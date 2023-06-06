defmodule Membrane.VideoCompositor.Transformations.CornersRounding do
  @moduledoc """
  Describe corners rounding transformation parameter.
  Corner rounding transformation can be imagined as placing four circles with specified radius
  adjoining to frame borders, placed inside frame and making space between circle edge and
  nearest frame corner transparent.
  ## Values
  - border_radius: non negative integer representing radius of circle "cutting"
  frame corner part.
  ## Examples
    Example struct describing transformation which rounds corners with 100 pixel radius:

      iex> alias Membrane.VideoCompositor.Transformations.CornersRounding
      Membrane.VideoCompositor.Transformations.CornersRounding
      iex> %CornersRounding{ border_radius: 100 }
      %Membrane.VideoCompositor.Transformations.CornersRounding{
        border_radius: 100
      }
  """

  @typedoc """
  Describe cropping transformation parameter.
  """
  @type t :: %__MODULE__{
          border_radius: non_neg_integer()
        }

  @enforce_keys [:border_radius]
  defstruct @enforce_keys
end
