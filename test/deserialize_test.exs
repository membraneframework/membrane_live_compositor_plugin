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
    # Native.test(
    #   [
    #     video_1: {:video, %Membrane.VideoCompositor.Scene.Video{input: {Membrane.Pad, :video, 1}}},
    #     video_2: {:video, %Membrane.VideoCompositor.Scene.Video{input: {Membrane.Pad, :video, 2}}},
    #     video_3: {:video, %Membrane.VideoCompositor.Scene.Video{input: {Membrane.Pad, :video, 3}}},
    #     video_4: {:video, %Membrane.VideoCompositor.Scene.Video{input: {Membrane.Pad, :video, 4}}},
    #     rounded_1:
    #       {:texture,
    #        %Membrane.VideoCompositor.Scene.RustlerFriendly.Texture{
    #          input: :video_1,
    #          transformations: [
    #            "%Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding{border_radius: 100}"
    #          ],
    #          resolution: :transformed_input_resolution
    #        }},
    #     rounded_2:
    #       {:texture,
    #        %Membrane.VideoCompositor.Scene.RustlerFriendly.Texture{
    #          input: :video_2,
    #          transformations: [
    #            "%Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding{border_radius: 100}"
    #          ],
    #          resolution: :transformed_input_resolution
    #        }},
    #     rounded_3:
    #       {:texture,
    #        %Membrane.VideoCompositor.Scene.RustlerFriendly.Texture{
    #          input: :video_3,
    #          transformations: [
    #            "%Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding{border_radius: 100}"
    #          ],
    #          resolution: :transformed_input_resolution
    #        }},
    #     rounded_4:
    #       {:texture,
    #        %Membrane.VideoCompositor.Scene.RustlerFriendly.Texture{
    #          input: :video_4,
    #          transformations: [
    #            "%Membrane.VideoCompositor.Examples.Mock.Transformations.CornersRounding{border_radius: 100}"
    #          ],
    #          resolution: :transformed_input_resolution
    #        }},
    #     final_object:
    #       {:layout,
    #        "%Membrane.VideoCompositor.Examples.Mock.Layouts.Overlay{overlay_spec: %{background: %Membrane.VideoCompositor.Examples.Mock.Layouts.Position{top_left_corner: {0.0, 0.0}, width: 1.0, height: 1.0, z_value: 0.0}, bottom_left: %Membrane.VideoCompositor.Examples.Mock.Layouts.Position{top_left_corner: {0.0, 0.6666666666666666}, width: 0.5925925925925926, height: 0.3333333333333333, z_value: 1.0}, center_left: %Membrane.VideoCompositor.Examples.Mock.Layouts.Position{top_left_corner: {0.0, 0.3333333333333333}, width: 0.5925925925925926, height: 0.3333333333333333, z_value: 1.0}, top_left: %Membrane.VideoCompositor.Examples.Mock.Layouts.Position{top_left_corner: {0.0, 0.0}, width: 0.5925925925925926, height: 0.3333333333333333, z_value: 1.0}}, inputs: %{background: :video_4, bottom_left: :video_3, center_left: :video_2, top_left: :video_1}, resolution: %Membrane.VideoCompositor.Scene.Resolution{width: 1920, height: 1080}}"}
    #   ]
    # )
  end
end
