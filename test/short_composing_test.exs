defmodule Membrane.VideoCompositor.ComposingTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline

  test "Checks composition and raw video pipeline on 3s 720p 1fps raw video" do
    input_paths = %{
      first_raw_video_path: "./test/fixtures/short_videos/input_3s_720p_1fps.raw",
      second_raw_video_path: "./test/fixtures/short_videos/input_3s_720p_1fps.raw"
    }

    output_path = "./test/fixtures/tmp_dir/output_3s_1280x1440_1fps.raw"
    composed_video_path = "./test/fixtures/short_videos/composed_video_3s_1280x1440_1fps.raw"

    video_caps = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :nx

    test_raw_pipeline_and_composing(
      input_paths,
      output_path,
      composed_video_path,
      video_caps,
      implementation
    )
  end

  defp test_raw_pipeline_and_composing(
         input_paths,
         output_path,
         composed_video_path,
         video_caps,
         implementation
       ) do
    options = %{
      paths: %{
        first_raw_video_path: input_paths.first_raw_video_path,
        second_raw_video_path: input_paths.second_raw_video_path,
        output_path: output_path
      },
      caps: video_caps,
      implementation: implementation
    }

    assert {:ok, pid} =
             TestingPipeline.start_link(
               module: Membrane.VideoCompositor.PipelineRaw,
               custom_args: options
             )

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :file_sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)

    assert {:ok, out_video} = File.read(output_path)
    assert {:ok, composed_video} = File.read(composed_video_path)

    assert out_video == composed_video

    File.rm!(output_path)
  end
end
