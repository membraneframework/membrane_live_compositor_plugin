defmodule Membrane.VideoCompositor.Examples.Hard do
  @moduledoc """
  A hard example takes three videos, applies varied transformations to them, and puts
  them together on the final canvas
  - The first video is simply rotated and then put in the top left corner
  - The second video is merged with the first video. The result gets
  corner rounding and is put in the top right corner
  - The third video is turned into a ball and put in the middle bottom of the screen
  """

  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.{Grid, Merging}
  alias Membrane.VideoCompositor.Examples.Mock.Transformations.{Rotate, ToBall}
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.{Layout, Resolution, Texture}

  @rotate %Rotate{degrees: 90}
  @ball ToBall
  @corners_rounding %CornersRounding{border_radius: 5}
  @three_vids_grid %Grid{videos_count: 3}
  @merging Merging

  %Scene{
    objects: [
      rotated: %Texture{
        input: :video_1,
        transformations: [@rotate]
      },
      merged: %Layout{
        inputs_map: %{
          video_1: 0,
          video_2: 1
        },
        layout: @merging,
        resolution: :video_1
      },
      rounded: %Texture{input: :merged, transformations: [@corners_rounding]},
      ball: %Texture{input: :video_3, transformations: [@ball]},
      final_object: %Layout{
        inputs_map: %{
          rotated: :top_left,
          rounded: :top_right,
          ball: :bottom
        },
        layout: @three_vids_grid,
        resolution: %Resolution{width: 1920, height: 1080}
      }
    ],
    output: :final_objects
  }

  # Here's how I would like for in to look in the final version, with macros etc.
  # I think that design would be more coherent with membrane.

  # scene = %Scene{
  #   elements: %{
  #     rotate: %Rotate{degrees: 90},
  #     ball: ToBall,
  #     corners_rounding: %CornersRounding{border_radius: 5},
  #     three_vids_grid: %Grid{videos_count: 3},
  #     merging: Merging
  #   },
  #   rendering: [
  #     link(:video_1) |> with_transforms([:rotate]) |> via_in(:top_left) |> to(:three_vids_grid),
  #     link(:video_1) |> via_in(0) |> to(:merging),
  #     link(:video_2) |> via_in(1) |> to(:merging),
  #     link(:merging) |> via_in(:top_left) |> to(:three_vids_grid)
  #     link(:video_3) |> with_transforms([:ball]) |> via_in(:bottom) |> to(:three_vids_grid)
  #     link(:three_vids_grid) |> to(:output)
  #   ]
  # }
end
