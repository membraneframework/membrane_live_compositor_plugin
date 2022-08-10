defmodule Membrane.VideoCompositor.ComposingTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Test.Utility, as: TestingUtility

  @filter_description "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"

  describe "Checks composition and raw video pipeline on" do
    @describetag :tmp_dir

    test "3s 720p 1fps raw video", %{tmp_dir: tmp_dir} do
      video_caps = %RawVideo{
        width: 1280,
        height: 720,
        framerate: {1, 1},
        pixel_format: :I420,
        aligned: nil
      }

      duration = 3

      {input_path, output_path, reference_path} =
        TestingUtility.prepare_testing_video(
          video_caps,
          duration,
          "raw",
          tmp_dir,
          "short_videos"
        )

      input_paths = %{
        first_raw_video_path: input_path,
        second_raw_video_path: input_path
      }

      implementation = :nx

      TestingUtility.generate_raw_ffmpeg_reference(
        input_path,
        video_caps,
        reference_path,
        @filter_description
      )

      test_raw_pipeline_and_composing(
        input_paths,
        output_path,
        reference_path,
        video_caps,
        implementation
      )
    end

    @tag long: true
    test "10s 720p 1fps raw video", %{tmp_dir: tmp_dir} do
      input_paths = %{
        first_raw_video_path: "./test/fixtures/long_videos/input_10s_720p_1fps.raw",
        second_raw_video_path: "./test/fixtures/long_videos/input_10s_720p_1fps.raw"
      }

      output_path = Path.join(tmp_dir, "output_10s_1280x1440_1fps.raw")
      composed_video_path = "./test/fixtures/long_videos/composed_video_10s_1280x1440_1fps.raw"

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
  end
end
