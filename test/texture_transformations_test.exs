defmodule Membrane.VideoCompositor.Test.TextureTransformations do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}
  alias Membrane.VideoCompositor.RustStructs.VideoPlacement
  alias Membrane.VideoCompositor.Test.Support.Pipeline.Raw, as: PipelineRaw
  alias Membrane.VideoCompositor.Test.Support.Utils
  alias Membrane.VideoCompositor.VideoTransformations

  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.{
    CornersRounding,
    Cropping
  }

  @hd_video %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  describe "Checks corners rounding and cropping" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "1 frame 720p raw", %{tmp_dir: tmp_dir} do
      crop = %Cropping{
        top_left_corner: {0.5, 0.5},
        crop_size: {0.5, 0.5}
      }

      corners_round = %CornersRounding{
        corner_rounding_radius: 0.1
      }

      video_spec = %InputStream{
        placement: nil,
        transformations: %VideoTransformations{
          texture_transformations: [crop, corners_round]
        },
        caps: @hd_video,
        input: nil
      }

      test_transformations(@hd_video, 1, tmp_dir, "short_videos", video_spec)
    end
  end

  @spec test_transformations(
          Membrane.RawVideo.t(),
          non_neg_integer(),
          binary(),
          binary(),
          InputStream.t()
        ) ::
          nil
  defp test_transformations(video_caps, duration, tmp_dir, sub_dir_name, video_spec) do
    {input_path, _output_path, _reference_path} =
      Utils.prepare_testing_video(
        video_caps,
        duration,
        "raw",
        tmp_dir,
        sub_dir_name
      )

    out_caps = %RawVideo{
      video_caps
      | width: video_caps.width * 2,
        height: video_caps.height * 2
    }

    output_path =
      Path.join(
        tmp_dir,
        "out_#{duration}s_#{out_caps.width}x#{out_caps.height}_#{div(elem(out_caps.framerate, 0), elem(out_caps.framerate, 1))}fps.raw"
      )

    reference_path = "test/videos/texture_transformations/ref_cropping_and_corners_rounding.yuv"

    positions = [
      {0, 0},
      {video_caps.width, 0},
      {0, video_caps.height},
      {video_caps.width, video_caps.height}
    ]

    background_video = %InputStream{
      placement: %VideoPlacement{
        base_position: {0, 0},
        base_size: {@hd_video.width * 2, @hd_video.height * 2}
      },
      transformations: %VideoTransformations{
        texture_transformations: []
      },
      caps: @hd_video,
      input: input_path
    }

    inputs =
      for(
        pos <- positions,
        do: %InputStream{
          video_spec
          | placement: %VideoPlacement{
              base_position: pos,
              base_size: {@hd_video.width, @hd_video.height},
              base_z_value: 0.5
            },
            input: input_path
        }
      )

    middle_video = %InputStream{
      video_spec
      | placement: %VideoPlacement{
          base_position: {-@hd_video.width, -@hd_video.height},
          base_size: {@hd_video.width * 2, @hd_video.height * 2},
          base_z_value: 0.2
        },
        input: input_path
    }

    options = %Options{
      inputs: inputs ++ [middle_video] ++ [background_video],
      output: output_path,
      caps: out_caps
    }

    assert {:ok, pid} = TestingPipeline.start_link(module: PipelineRaw, custom_args: options)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)

    assert Utils.compare_contents_with_error(output_path, reference_path)
  end
end
