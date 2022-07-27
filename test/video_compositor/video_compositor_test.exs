defmodule Membrane.VideoCompositor.Test do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.Testing.Pipeline, as: TestPipeline
  alias Membrane.VideoCompositor.Test.Utility

  @tag :tmp_dir
  test "xxx", %{tmp_dir: tmp_dir} do
    video_width = 1280
    video_height = 720
    video_framerate = 30
    implementation = :ffmpeg

    {in_path, out_path, _ref_path} =
      Utility.prepare_paths("2s_30fps.raw", "ref-all.h264", tmp_dir)

    IO.inspect(in_path)
    IO.inspect(out_path)

    options = %{
      first_raw_video_path: in_path,
      second_raw_video_path: in_path,
      output_path: out_path,
      video_width: video_width,
      video_height: video_height,
      video_framerate: video_framerate,
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

    # Helpers.create_ffmpeg_reference(
    #   in_path,
    #   ref_path,
    #   "drawtext=text='My text':fontcolor=white:box=1:boxcolor=orange:borderw=1:bordercolor=red:fontsize=35:x=(w-text_w)/2:y=w/100"
    # )

    # Helpers.compare_contents(out_path, ref_path)
  end
end
