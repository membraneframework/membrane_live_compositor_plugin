defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping do
  @moduledoc """
  Describe cropping texture transformation parameters.
  ## Values
  - crop_top_left_corner: tuple representing coords (in [0, 1] range) of
  top left corner of the visible part of video
  - crop_size: tuple representing width and height (in [0, 1] range) of
  the visible part of video
  - cropped_video_position: optional atom, describe whether cropped video part should
  remain in cropped part or should be in position of video before transformation.
  For more reference see Examples section below.


  ## Examples
    Struct describing transformation, which displays only bottom right quarter of input
    video, with cropped part remaining in its position:

      iex> alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping
      Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping
      iex> %Cropping{
        crop_top_left_corner: {0.5, 0.5},
        crop_size: {0.5, 0.5},
        cropped_video_position: :crop_part_position # can be omitted, this is default value
      }
      %Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping{
        crop_top_left_corner: {0.5, 0.5},
        crop_size: {0.5, 0.5},
        cropped_video_position: :crop_part_position
      }

    Struct describing transformation, which displays only right part
    of input video in left part of input video:

      iex> alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping
        Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping
        iex> %Cropping{
          crop_top_left_corner: {0.5, 0.0},
          crop_size: {0.5, 1.0},
          cropped_video_position: :input_position
        }
        %Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping{
          crop_top_left_corner: {0.5, 0.0},
          crop_size: {0.5, 1.0},
          cropped_video_position: :input_position
        }
  """

  @typedoc """
  Describe cropping texture transformation parameters.
  """
  @type t :: %__MODULE__{
          crop_top_left_corner: {float(), float()},
          crop_size: {float(), float()},
          cropped_video_position: :input_position | :crop_part_position
        }

  @enforce_keys [:crop_top_left_corner, :crop_size]
  defstruct [:crop_top_left_corner, :crop_size, cropped_video_position: :crop_part_position]
end
