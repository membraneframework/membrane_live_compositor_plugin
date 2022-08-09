defmodule Membrane.VideoCompositor.PipelineTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Test.Utility, as: TestingUtility

  describe "Checks h264 nx pipeline on " do
    test "2s 720p 30fps video" do
      video_caps = %RawVideo{
        width: 1280,
        height: 720,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :nx
      duration = 2
      test_h264_pipeline(video_caps, duration, implementation, "short_videos")
    end

    test "1s 1080p 30fps video" do
      video_caps = %RawVideo{
        width: 1920,
        height: 1080,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :nx
      duration = 1

      test_h264_pipeline(video_caps, duration, implementation, "short_videos")
    end

    @tag long: true
    test "30s 720p 30fps video" do
      video_caps = %RawVideo{
        width: 1280,
        height: 720,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :nx

      duration = 30

      test_h264_pipeline(video_caps, duration, implementation, "long_videos")
    end

    @tag long: true, timeout: 100_000
    test "60s 1080p 30fps video" do
      video_caps = %RawVideo{
        width: 1920,
        height: 1080,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :nx

      duration = 60

      test_h264_pipeline(video_caps, duration, implementation, "long_videos")
    end
  end

  describe "Checks h264 ffmpeg pipeline on " do
    test "2s 720p 30fps video" do
      video_caps = %RawVideo{
        width: 1280,
        height: 720,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :ffmpeg
      duration = 2
      test_h264_pipeline(video_caps, duration, implementation, "short_videos")
    end

    test "1s 1080p 30fps video" do
      video_caps = %RawVideo{
        width: 1920,
        height: 1080,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :ffmpeg
      duration = 1

      test_h264_pipeline(video_caps, duration, implementation, "short_videos")
    end

    @tag long: true
    test "30s 720p 30fps video" do
      video_caps = %RawVideo{
        width: 1280,
        height: 720,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :ffmpeg

      duration = 30

      test_h264_pipeline(video_caps, duration, implementation, "long_videos")
    end

    @tag long: true, timeout: 100_000
    test "60s 1080p 30fps video" do
      video_caps = %RawVideo{
        width: 1920,
        height: 1080,
        framerate: {30, 1},
        pixel_format: :I420,
        aligned: nil
      }

      implementation = :ffmpeg

      duration = 60

      test_h264_pipeline(video_caps, duration, implementation, "long_videos")
    end
  end

  defp test_h264_pipeline(video_caps, duration, implementation, sub_dir_name) do
    {input_file_name, out_file_name, _ref_file_name} =
      TestingUtility.prepare_testing_video(video_caps, duration, "h264", sub_dir_name)

    options = %{
      paths: %{
        first_h264_video_path: input_file_name,
        second_h264_video_path: input_file_name,
        output_path: out_file_name
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
