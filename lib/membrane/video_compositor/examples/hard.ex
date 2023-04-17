defmodule Membrane.VideoCompositor.Examples.Hard do
  @moduledoc """
  A hard example takes three videos, applies varied transformations to them, and puts
  them together on the final canvas. Membrane logo is used as a static background image.

  - The first video is simply rotated and then put in the top left corner
  - The second video is merged with the first video. The result gets
  corner rounded and is put in the top right corner
  - The third video is turned into a ball and put in the middle bottom of the screen
  """

  alias Membrane.VideoCompositor.TextureTransformations.CornersRounding

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.{Grid, Merging, Overlay, Position}
  alias Membrane.VideoCompositor.Examples.Mock.Transformations.{Rotate, ToBall}
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Object.Input.{StaticFrame, Video}
  alias Membrane.VideoCompositor.Scene.Object.Texture
  alias Membrane.VideoCompositor.Scene.Resolution

  @rotate %Rotate{degrees: 90}
  @ball ToBall
  @corners_rounding %CornersRounding{border_radius: 5}
  @three_vids_grid %Grid{videos_count: 3, inputs: nil, resolution: nil}

  @full_hd %Resolution{width: 1920, height: 1080}
  @full_video_position %Position{
    top_left_corner: {0.0, 0.0},
    width: 1.0,
    height: 1.0,
    z_value: 0.0
  }
  @background_overlay %Overlay{
    overlay_spec: %{
      background: @full_video_position,
      top: %Position{
        @full_video_position
        | z_value: 1.0
      }
    },
    inputs: %{},
    resolution: nil
  }

  @background_frame_data File.read!(
                           "lib/membrane/video_compositor/examples/mock/assets/membrane_logo.raw"
                         )

  %Scene{
    objects: [
      video_1: %Video{input_pad: :video_1},
      video_2: %Video{input_pad: :video_2},
      video_3: %Video{input_pad: :video_3},
      static_background: %StaticFrame{
        frame: @background_frame_data,
        stream_format: @full_hd
      },
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
      grid: %Grid{
        @three_vids_grid
        | inputs: %{
            0 => :rotated,
            1 => :rounded,
            2 => :ball
          },
          resolution: @full_hd
      },
      final_object: %Overlay{
        @background_overlay
        | inputs: %{
            top: :grid,
            background: :static_background
          },
          resolution: @full_hd
      }
    ],
    output: :final_object
  }
end
