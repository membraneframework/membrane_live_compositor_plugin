defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding do
  @moduledoc """
  Describe corners rounding texture transformation.
  """

  @typedoc """
  Describe cropping texture transformation parameter.
  Corner rounding transformation can be imagined as placing four circles with specified radius
  adjoining to frame corners, placed inside frame and making space between circle edge and
  nearest frame corner transparent.
  ## Values
  - corner_rounding_radius: [0, 1] range float representing radius of circle "cutting"
  frame corner part. [0, 1] range is mapped into pixels based on video width, meaning
  corner_rounding_radius equals 0.1 in FullHD video makes 192 pixels long radius of circle.
  ## Examples
    Example struct describing transformation which rounds corners:

      iex> alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding
      Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding
      iex> %CornersRounding{ corner_rounding_radius: 0.1 }
      %Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding{
        corner_rounding_radius: 0.1
      }
  """
  @type t :: %__MODULE__{
          corner_rounding_radius: float()
        }

  @enforce_keys [:corner_rounding_radius]
  defstruct @enforce_keys
end
