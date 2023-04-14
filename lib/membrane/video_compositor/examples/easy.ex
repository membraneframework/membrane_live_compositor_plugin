defmodule Membrane.VideoCompositor.Examples.Easy do
  @moduledoc """
  An easy example simulates the layout of a video conferencing app.

  There are 4 video inputs. All of them get their corners rounded. Then,
  one of them is chosen as a main video (which takes most of the screen),
  while the rest are scaled-down and put in a side strip on top of the main video.
  """

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.{Overlay, Position}
  alias Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Object.Input.Video
  alias Membrane.VideoCompositor.Scene.Object.Texture
  alias Membrane.VideoCompositor.Scene.Resolution

  @one_third 1.0 / 3.0
  @sixteen_ninths 16.0 / 9.0
  @corners_rounding %CornersRounding{border_radius: 100}

  @strip_overlay %Overlay{
    overlay_spec: %{
      background: %Position{
        top_left_corner: {0.0, 0.0},
        width: 1.0,
        height: 1.0,
        z_value: 0.0
      },
      top_left: %Position{
        top_left_corner: {0.0, 0.0},
        width: @sixteen_ninths * @one_third,
        height: @one_third,
        z_value: 1.0
      },
      center_left: %Position{
        top_left_corner: {0.0, @one_third},
        width: @sixteen_ninths * @one_third,
        height: @one_third,
        z_value: 1.0
      },
      bottom_left: %Position{
        top_left_corner: {0.0, 2 * @one_third},
        width: @sixteen_ninths * @one_third,
        height: @one_third,
        z_value: 1.0
      }
    },
    inputs: %{},
    resolution: nil
  }

  %Scene{
    objects: [
      video_1: %Video{input_pad: :video_1},
      video_2: %Video{input_pad: :video_2},
      video_3: %Video{input_pad: :video_3},
      video_4: %Video{input_pad: :video_4},
      rounded_1: %Texture{
        input: :video_1,
        transformations: [@corners_rounding]
      },
      rounded_2: %Texture{
        input: :video_2,
        transformations: [@corners_rounding]
      },
      rounded_3: %Texture{
        input: :video_3,
        transformations: [@corners_rounding]
      },
      rounded_4: %Texture{
        input: :video_4,
        transformations: [@corners_rounding]
      },
      final_object: %Overlay{
        @strip_overlay
        | inputs: %{
            top_left: :rounded_1,
            center_left: :rounded_2,
            bottom_left: :rounded_3,
            background: :rounded_4
          },
          resolution: %Resolution{width: 1920, height: 1080}
      }
    ],
    output: :final_object
  }
end
