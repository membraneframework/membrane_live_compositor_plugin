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
  alias Membrane.VideoCompositor.Scene.{Resolution, Texture}

  @rotate %Rotate{degrees: 90}
  @ball ToBall
  @corners_rounding %CornersRounding{border_radius: 5}
  @three_vids_grid %Grid{videos_count: 3, inputs: nil, resolution: nil}

  %Scene{
    objects: [
      rotated: %Texture{
        input: :video_1,
        transformations: [@rotate]
      },
      merged: %Merging{
        inputs: %{
          first: :video_1,
          second: :video_2
        },
        resolution: :video_1
      },
      rounded: %Texture{input: :merged, transformations: [@corners_rounding]},
      ball: %Texture{input: :video_3, transformations: [@ball]},
      final_object: %Grid{
        @three_vids_grid
        | inputs: %{
            0 => :rotated,
            1 => :rounded,
            2 => :ball
          },
          resolution: %Resolution{width: 1920, height: 1080}
      }
    ],
    output: :final_object
  }

  # Here's how I would like for it to look in the final version, with macros etc.
  # I think that this design would be more coherent with a Membrane ecosystem.

  # scene = %Scene{
  #   elements: %{
  #     rotate: %Rotate{degrees: 90},
  #     to_ball: ToBall,
  #     corners_rounding: %CornersRounding{border_radius: 5},
  #     three_vids_grid: %Grid{@three_vids_grid | resolution: %Resolution{width: 1920, height: 1080}},
  #     merging: %Merging{inputs: {0 => nil, 1 => nil}, resolution %Resolution{width: 1920, height: 1080}}
  #   },
  #   rendering: [
  #     link(:video_1) |> with_transforms([:rotate]) |> via_in(0) |> to(:three_vids_grid),
  #     link(:video_1) |> via_in(0) |> to(:merging),
  #     link(:video_2) |> via_in(1) |> to(:merging),
  #     link(:merging) |> via_in(1) |> to(:three_vids_grid)
  #     link(:video_3) |> with_transforms([:to_ball]) |> via_in(2) |> to(:three_vids_grid)
  #     link(:three_vids_grid) |> to(:output)
  #   ]
  # }
end
