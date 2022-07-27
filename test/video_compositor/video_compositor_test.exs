defmodule Membrane.VideoCompositor.Test do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestPipeline
  alias Membrane.VideoCompositor.Test.Utility

  @tag :tmp_dir
  test "compose two raw videos using a pipeline", %{tmp_dir: tmp_dir} do
    video = %RawVideo{
      width: 1280,
      height: 720,
      framerate: 30,
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :ffmpeg
    duration = 3

    {in_path, out_path, ref_path} =
      Utility.prepare_paths(
        "#{video.framerate}s_#{video.framerate}fps.raw",
        "ref-all.h264",
        tmp_dir
      )

    Utility.generate_testing_raw_video(in_path, video, duration)

    options = %{
      first_raw_video_path: in_path,
      second_raw_video_path: in_path,
      output_path: out_path,
      video_width: video.width,
      video_height: video.height,
      video_framerate: video.framerate,
      implementation: implementation
    }

    assert {:ok, pid} =
             TestPipeline.start_link(%TestPipeline.Options{
               module: Membrane.VideoCompositor.Pipeline,
               custom_args: options
             })

    Membrane.VideoCompositor.Pipeline.play(pid)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :file_sink, :input, 7000)
    TestPipeline.terminate(pid, blocking?: true)

    Utility.create_ffmpeg_reference(
      in_path,
      ref_path,
      "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
    )

    Utility.compare_contents(out_path, ref_path)
  end
end
