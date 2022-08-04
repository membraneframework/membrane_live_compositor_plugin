defmodule Membrane.VideoCompositor.FFmpeg.Pipeline.Test do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Test.Utility

  @tag :tmp_dir
  test "compose two H264 videos using a ffmpeg in the pipeline", %{tmp_dir: tmp_dir} do
    video_caps = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {30, 1},
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :ffmpeg

    duration = 3

    {in_path, out_path, _ref_path} =
      Utility.prepare_testing_video(video_caps, duration, "h264", tmp_dir)

    options = %{
      paths: %{
        first_h264_video_path: in_path,
        second_h264_video_path: in_path,
        output_path: out_path
      },
      caps: video_caps,
      implementation: implementation
    }

    assert {:ok, pid} =
             TestingPipeline.start_link(%TestingPipeline.Options{
               module: Membrane.VideoCompositor.PipelineH264,
               custom_args: options
             })

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :file_sink, :input, 100_000)
    TestingPipeline.terminate(pid, blocking?: true)
  end
end
