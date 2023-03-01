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
  alias Membrane.VideoCompositor.Scene.{Resolution, Texture}

  @one_third 1.0 / 3.0
  @sixteen_tenths 16.0 / 9.0
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
        width: @sixteen_tenths * @one_third,
        height: @one_third,
        z_value: 1.0
      },
      center_left: %Position{
        top_left_corner: {0.0, @one_third},
        width: @sixteen_tenths * @one_third,
        height: @one_third,
        z_value: 1.0
      },
      bottom_left: %Position{
        top_left_corner: {0.0, 2 * @one_third},
        width: @sixteen_tenths * @one_third,
        height: @one_third,
        z_value: 1.0
      }
    },
    inputs: %{
      background: nil,
      top_left: nil,
      center_left: nil,
      bottom_left: nil
    },
    resolution: nil
  }

  %Scene{
    objects: [
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
            top_left: :video_1,
            center_left: :video_2,
            bottom_left: :video_3,
            background: :video_4
          },
          resolution: %Resolution{width: 1920, height: 1080}
      }
    ],
    output: :final_object
  }

  # Here's how I would like for in to look in the final version, with macros etc.
  # I think that design would be more coherent with membrane.

  # scene = %Scene{
  #   elements: %{
  #     corners_rounding: %CornersRounding{border_radius: 100},
  #     overlay: @strip_overlay
  #   },
  #   rendering: [
  #     link(:video_1) |> with_transforms([:corners_rounding]) |> via_in(:top_left) |> to(:overlay),
  #     link(:video_2) |> with_transforms([:corners_rounding]) |> via_in(:center_left) |> to(:overlay),
  #     link(:video_3) |> with_transforms([:corners_rounding]) |> via_in(:bottom_left) |> to(:overlay),
  #     link(:video_4) |> with_transforms([:corners_rounding]) |> via_in(:background) |> to(:overlay)
  #     link(:overlay) |> to(:output)
  #   ]
  # }
end
