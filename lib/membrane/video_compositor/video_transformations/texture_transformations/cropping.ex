defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping do
  @moduledoc """
  Describe cropping texture transformation parameters.
  ## Values
  - top_left_corner: tuple representing coords (in [0, 1] range) of
  top left corner of the visible part of video
  - crop_size: tuple representing width and height (in [0, 1] range) of
  the visible part of video
  ## Examples
    Struct describing transformation, which displays only bottom right corner of video:

      iex> alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping
      Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping
      iex> %Cropping{ top_left_corner: {0.5, 0.5}, crop_size: {0.5, 0.5} }
      %Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping{
        top_left_corner: {0.5, 0.5},
        crop_size: {0.5, 0.5}
      }
  """

  @typedoc """
  Describe cropping texture transformation parameters.
  """
  @type t :: %__MODULE__{
          top_left_corner: {float(), float()},
          crop_size: {float(), float()}
        }

  @enforce_keys [:top_left_corner, :crop_size]
  defstruct @enforce_keys
end
