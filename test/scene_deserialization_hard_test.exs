defmodule Membrane.VideoCompositor.Test.DeserializeHard do
  use ExUnit.Case

  alias Membrane.RawVideo

  alias Membrane.VideoCompositor.Native.Impl

  alias Membrane.VideoCompositor.Mock.Layouts.{Grid, Merging, Overlay, Position}
  alias Membrane.VideoCompositor.Mock.Transformations.{CornersRounding, Rotate, ToBall}
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Object.{InputImage, InputVideo, Texture}
  alias Membrane.VideoCompositor.Resolution

  @rotate %Rotate{degrees: 90}
  @ball ToBall
  @corners_rounding %CornersRounding{border_radius: 5}
  @three_vids_grid %Grid{videos_count: 3, inputs: nil, resolution: nil}

  @full_hd %Resolution{width: 1920, height: 1080}

  @full_hd_image %RawVideo{
    width: 1920,
    height: 1080,
    pixel_format: :I420,
    framerate: nil,
    aligned: true
  }

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

  # binary with placeholder data, matching size of
  # a single yuv420p full hd frame
  @background_frame_data <<0::3_110_400>>

  @scene %Scene{
    objects: [
      video_1: %InputVideo{input_pad: :video_1},
      video_2: %InputVideo{input_pad: :video_2},
      video_3: %InputVideo{input_pad: :video_3},
      static_background: %InputImage{
        frame: @background_frame_data,
        stream_format: @full_hd_image
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
            {:input, 0} => :rotated,
            {:input, 1} => :rounded,
            {:input, 2} => :ball
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

  test "deserialize" do
    assert :ok = Impl.test_scene_deserialization(Scene.encode(@scene))
  end
end
