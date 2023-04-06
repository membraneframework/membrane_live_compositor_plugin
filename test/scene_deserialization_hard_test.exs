defmodule Membrane.VideoCompositor.Test.DeserializeHard do
  use ExUnit.Case

  require Membrane.Pad

  alias Membrane.VideoCompositor.Wgpu.Native

  alias Membrane.VideoCompositor.Mock.Layouts.{Grid, Merging}
  alias Membrane.VideoCompositor.Mock.Transformations.{CornersRounding, Rotate, ToBall}
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Object.{InputVideo, Texture}
  alias Membrane.VideoCompositor.Scene.Resolution

  @rotate %Rotate{degrees: 90}
  @ball ToBall
  @corners_rounding %CornersRounding{border_radius: 5}
  @three_vids_grid %Grid{videos_count: 3, inputs: nil, resolution: nil}

  @scene %Scene{
    objects: [
      video_1: %InputVideo{input_pad: Membrane.Pad.ref(:video, 1)},
      video_2: %InputVideo{input_pad: Membrane.Pad.ref(:video, 2)},
      video_3: %InputVideo{input_pad: Membrane.Pad.ref(:video, 3)},
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
            {:input, 0} => :rotated,
            {:input, 1} => :rounded,
            {:input, 2} => :ball
          },
          resolution: %Resolution{width: 1920, height: 1080}
      }
    ],
    output: :final_object
  }

  test "deserialize" do
    assert :ok = Native.test_scene_deserialization(Scene.encode(@scene))
  end
end
