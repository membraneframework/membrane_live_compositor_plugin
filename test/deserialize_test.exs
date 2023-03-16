defmodule Membrane.VideoCompositor.Test.Deserialize do
  use ExUnit.Case

  require Membrane.Pad

  alias Membrane.VideoCompositor.Wgpu.Native

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.{Overlay, Position}
  alias Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Object.{InputVideo, Texture}
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
    inputs: %{
      background: nil,
      top_left: nil,
      center_left: nil,
      bottom_left: nil
    },
    resolution: nil
  }

  @scene %Scene{
    objects: [
      video_1: %InputVideo{input_pad: Membrane.Pad.ref(:video, 1)},
      video_2: %InputVideo{input_pad: Membrane.Pad.ref(:video, 2)},
      video_3: %InputVideo{input_pad: Membrane.Pad.ref(:video, 3)},
      video_4: %InputVideo{input_pad: Membrane.Pad.ref(:video, 4)},
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

  test "deserialize" do
    Native.test(Scene.encode(@scene))
  end
end
