defmodule Membrane.VideoCompositor.TextureTransformationsTest do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}
  alias Membrane.VideoCompositor.Scene.{BaseVideoPlacement, VideoConfig}
  alias Membrane.VideoCompositor.Support.Pipeline.Raw, as: PipelineRaw
  alias Membrane.VideoCompositor.Support.Utils
  alias Membrane.VideoCompositor.VideoTransformations

  alias Membrane.VideoCompositor.TextureTransformations.{
    CornersRounding,
    Cropping
  }

  @video_stream_format %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @duration 1
  @sub_dir_name "short_videos"

  @crop %Cropping{
    crop_top_left_corner: {0.5, 0.5},
    crop_size: {0.5, 0.5}
  }
  @corners_round %CornersRounding{
    border_radius: 100
  }
  @transformations %VideoTransformations{
    texture_transformations: [@crop, @corners_round]
  }

  @reference_path "test/fixtures/texture_transformations/ref_cropping_and_corners_rounding.yuv"

  describe "Checks corners rounding and cropping" do
    @describetag :tmp_dir
    test "1 frame 720p raw", %{tmp_dir: tmp_dir} do
      test_transformations(tmp_dir)
    end
  end

  @spec test_transformations(binary()) :: nil
  defp test_transformations(tmp_dir) do
    {input_path, _output_path, _reference_path} =
      Utils.prepare_testing_video(
        @video_stream_format,
        @duration,
        "raw",
        tmp_dir,
        @sub_dir_name
      )

    out_stream_format = %RawVideo{
      @video_stream_format
      | width: @video_stream_format.width * 2,
        height: @video_stream_format.height * 2
    }

    output_path =
      Path.join(
        tmp_dir,
        "out_#{@duration}s_#{out_stream_format.width}x#{out_stream_format.height}_#{div(elem(out_stream_format.framerate, 0), elem(out_stream_format.framerate, 1))}fps.raw"
      )

    positions = [
      {0, 0},
      {@video_stream_format.width, 0},
      {0, @video_stream_format.height},
      {@video_stream_format.width, @video_stream_format.height}
    ]

    background_video = %InputStream{
      video_config: %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {0, 0},
          size: {@video_stream_format.width * 2, @video_stream_format.height * 2}
        },
        transformations: VideoTransformations.empty()
      },
      stream_format: @video_stream_format,
      input: input_path
    }

    transformed_videos =
      Enum.map(positions, fn position ->
        %InputStream{
          input: input_path,
          video_config: %VideoConfig{
            placement: %BaseVideoPlacement{
              position: position,
              size: {@video_stream_format.width, @video_stream_format.height},
              z_value: 0.5
            },
            transformations: @transformations
          },
          stream_format: @video_stream_format
        }
      end)

    middle_video = %InputStream{
      input: input_path,
      video_config: %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {-@video_stream_format.width, -@video_stream_format.height},
          size: {@video_stream_format.width * 2, @video_stream_format.height * 2},
          z_value: 0.2
        },
        transformations: @transformations
      },
      stream_format: @video_stream_format
    }

    options = %Options{
      inputs: transformed_videos ++ [middle_video] ++ [background_video],
      output: output_path,
      output_stream_format: out_stream_format
    }

    pipeline = TestingPipeline.start_link_supervised!(module: PipelineRaw, custom_args: options)
    assert_pipeline_play(pipeline)
    assert_end_of_stream(pipeline, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pipeline, blocking?: true)

    assert Utils.compare_contents_with_error(output_path, @reference_path)
  end
end
