defmodule Membrane.VideoCompositor.TimestampOffsetTest do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Scene.{BaseVideoPlacement, VideoConfig}
  alias Membrane.VideoCompositor.Support.Pipeline.H264, as: PipelineH264
  alias Membrane.VideoCompositor.Support.Utils
  alias Membrane.VideoCompositor.VideoTransformations

  @hd_video %RawVideo{
    width: 1280,
    height: 720,
    framerate: {30, 1},
    pixel_format: :I420,
    aligned: true
  }

  @empty_video_transformations VideoTransformations.empty()

  describe "Checks timestamp_offset function on pipeline with" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "0s offset option", %{tmp_dir: tmp_dir} do
      test_video_offset_option(@hd_video, 0, 2, "timestamp_offset_test_videos", tmp_dir)
    end

    @tag wgpu: true
    test "2s offset option", %{tmp_dir: tmp_dir} do
      test_video_offset_option(@hd_video, 2, 2, "timestamp_offset_test_videos", tmp_dir)
    end
  end

  defp test_video_offset_option(
         video_stream_format,
         timestamp_offset,
         duration,
         sub_dir_name,
         tmp_dir
       ) do
    options =
      prepare_pipeline_options(
        video_stream_format,
        timestamp_offset,
        duration,
        sub_dir_name,
        tmp_dir
      )

    pipeline = TestingPipeline.start_link_supervised!(module: PipelineH264, custom_args: options)
    assert_pipeline_play(pipeline)
    assert_end_of_stream(pipeline, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pipeline, blocking?: true)
  end

  defp prepare_pipeline_options(
         video_stream_format,
         timestamp_offset,
         duration,
         sub_dir_name,
         tmp_dir
       ) do
    alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}

    {input_path, _output_path, _ref_file_name} =
      Utils.prepare_testing_video(
        video_stream_format,
        duration,
        "h264",
        tmp_dir,
        sub_dir_name
      )

    output_path =
      Path.join(
        tmp_dir,
        "out_#{duration}s_#{video_stream_format.width}x#{video_stream_format.height}_#{div(elem(video_stream_format.framerate, 0), elem(video_stream_format.framerate, 1))}fps.raw"
      )

    inputs = [
      %InputStream{
        input: input_path,
        video_config: %VideoConfig{
          placement: %BaseVideoPlacement{
            position: {0, 0},
            size: {video_stream_format.width, video_stream_format.height}
          },
          transformations: @empty_video_transformations
        },
        timestamp_offset: timestamp_offset,
        stream_format: video_stream_format
      }
    ]

    options = %Options{
      inputs: inputs,
      output: output_path,
      output_stream_format: video_stream_format
    }

    options
  end
end
