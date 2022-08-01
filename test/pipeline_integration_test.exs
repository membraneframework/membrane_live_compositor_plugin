ExUnit.start()

defmodule Membrane.VideoCompositor.PipelineTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline

  test "Checks h264 pipeline on 30s 720 videos" do
    input_paths = %{
      first_h264_video_path: "./test/fixtures/input_30s_720p.h264",
      second_h264_video_path: "./test/fixtures/input_30s_720p.h264"
    }

    output_path = "./test/fixtures/output_30s_1280x1440.h264"

    video_caps = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {30, 1},
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :nx

    test_h264_pipeline(input_paths, output_path, video_caps, implementation)
  end

  test "Checks h264 pipeline on 60s 1080p videos" do
    input_paths = %{
      first_h264_video_path: "./test/fixtures/input_60s_1080p.h264",
      second_h264_video_path: "./test/fixtures/input_60s_1080p.h264"
    }

    output_path = "./test/fixtures/output_60s_1920x2160.h264"

    video_caps = %RawVideo{
      width: 1920,
      height: 1080,
      framerate: {30, 1},
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :nx

    test_h264_pipeline(input_paths, output_path, video_caps, implementation)
  end

  defp test_h264_pipeline(input_paths, output_path, video_caps, implementation) do
    options = %{
      paths: %{
        first_h264_video_path: input_paths.first_h264_video_path,
        second_h264_video_path: input_paths.first_h264_video_path,
        output_path: output_path
      },
      caps: video_caps,
      implementation: implementation
    }

    assert {:ok, pid} =
             TestingPipeline.start_link(
               module: Membrane.VideoCompositor.PipelineH264,
               custom_args: options
             )

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :file_sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)
  end
end
