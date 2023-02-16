defmodule Example do
  @moduledoc """
  This module covers two examples for scene API.

  An easy example simulates the layout of a video conferencing app.
  There are 4 video inputs. All of them get their corners rounded. Then,
  one of them is chosen as a main video (which takes most of the screen),
  while the rest are scaled-down and put in a side strip on top of the main video.

  A hard example takes three videos, applies varied transformations to them, and puts
  them together on the final canvas
  - The first video is simply rotated and then put in the top left corner
  - The second video is merged with the first video. The result gets
  corner rounding and is put in the top right corner
  - The third video is turned into a ball and put in the middle bottom of the screen
  """

  alias Membrane.VideoCompositor.{Canvas, Compound, Scene, Texture}
  alias Membrane.VideoCompositor.Compound.BaseSize
  alias Mock.{CornerRounding, Grid, Merging, Overlay, Rotate, ToBall}

  @easy %Scene{
    alternations: [
      rounding: %CornerRounding{pixels: 10, degrees: 60}
    ],
    layouts: [
      overlay: Overlay,
      strip: Grid
    ],
    objects: [
      rounded_1: %Texture{input: :video_1, transformations: [:rounding]},
      rounded_2: %Texture{input: :video_2, transformations: [:rounding]},
      rounded_3: %Texture{input: :video_3, transformations: [:rounding]},
      rounded_4: %Texture{input: :video_4, transformations: [:rounding]},
      strip: %Compound{
        base_size: %BaseSize{height: 1080, width: 480},
        inputs_map: %{
          rounded_1: :top,
          rounded_2: :middle,
          rounded_3: :bottom
        },
        layout: :strip
      },
      final_object: %Compound{
        base_size: %BaseSize{height: 1080, width: 1920},
        inputs_map: %{
          strip: 1.0,
          rounded_4: 0.0
        },
        layout: :overlay
      }
    ],
    render: :final_object
  }

  @hard %Scene{
    alternations: [
      rotate: %Rotate{degrees: 90},
      ball: ToBall,
      rounding: %CornerRounding{pixels: 5, degrees: 90}
    ],
    layouts: [
      grid: Grid,
      merging: %Merging{videos_num: 2}
    ],
    objects: [
      rotated: %Canvas{input: :video_1, transformations: [:rotate]},
      merged: %Compound{
        base_size: :video_1,
        layout: :merging,
        inputs_map: %{video_1: 1, video_2: 2}
      },
      rounded: %Texture{input: :merged, transformations: [:rounding]},
      ball: %Canvas{input: :video_3, transformations: [:ball]},
      final_object: %Compound{
        base_size: %BaseSize{height: 1080, width: 1920},
        layout: :grid,
        inputs_map: %{
          rotated: :top_left,
          rounded: :top_right,
          ball: :bottom
        }
      }
    ],
    render: :final_object
  }
end
