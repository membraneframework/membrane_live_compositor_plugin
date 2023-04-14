defmodule Membrane.VideoCompositor.PipelineIntegrationTest do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.Support.Pipeline.H264, as: PipelineH264
  alias Membrane.VideoCompositor.Support.Utils

  @hd_video %RawVideo{
    width: 1280,
    height: 720,
    framerate: {30, 1},
    pixel_format: :I420,
    aligned: true
  }

  @full_hd_video %RawVideo{
    width: 1920,
    height: 1080,
    framerate: {30, 1},
    pixel_format: :I420,
    aligned: true
  }

  @empty_video_transformations Membrane.VideoCompositor.VideoTransformations.empty()

  describe "Checks h264 pipeline on merging four videos on 2x2 grid" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "2s 720p 30fps h264", %{tmp_dir: tmp_dir} do
      test_h264_pipeline(@hd_video, 2, "short_videos", tmp_dir)
    end

    @tag wgpu: true
    test "1s 1080p 30fps h264", %{tmp_dir: tmp_dir} do
      test_h264_pipeline(@full_hd_video, 1, "short_videos", tmp_dir)
    end

    @tag long_wgpu: true, timeout: 1_000_000
    test "30s 720p 30fps h264", %{tmp_dir: tmp_dir} do
      test_h264_pipeline(@hd_video, 30, "long_videos", tmp_dir)
    end

    @tag long_wgpu: true, timeout: 1_000_000
    test "60s 1080p 30fps h264", %{tmp_dir: tmp_dir} do
      test_h264_pipeline(@full_hd_video, 30, "long_videos", tmp_dir)
    end
  end

  defp test_h264_pipeline(video_stream_format, duration, sub_dir_name, tmp_dir) do
    alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}

    {input_path, _output_path, _ref_file_name} =
      Utils.prepare_testing_video(
        video_stream_format,
        duration,
        "h264",
        tmp_dir,
        sub_dir_name
      )

    out_stream_format = %RawVideo{
      video_stream_format
      | width: video_stream_format.width * 2,
        height: video_stream_format.height * 2
    }

    output_path =
      Path.join(
        tmp_dir,
        "out_#{duration}s_#{out_stream_format.width}x#{out_stream_format.height}_#{div(elem(out_stream_format.framerate, 0), elem(out_stream_format.framerate, 1))}fps.raw"
      )

    positions = [
      {0, 0},
      {video_stream_format.width, 0},
      {0, video_stream_format.height},
      {video_stream_format.width, video_stream_format.height}
    ]

    inputs =
      for pos <- positions,
          do: %InputStream{
            placement: %BaseVideoPlacement{
              position: pos,
              size: {video_stream_format.width, video_stream_format.height}
            },
            transformations: @empty_video_transformations,
            stream_format: video_stream_format,
            input: input_path
          }

    options = %Options{
      inputs: inputs,
      output: output_path,
      stream_format: out_stream_format
    }

    pipeline = TestingPipeline.start_link_supervised!(module: PipelineH264, custom_args: options)
    assert_pipeline_play(pipeline)
    assert_end_of_stream(pipeline, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pipeline, blocking?: true)
  end
end
