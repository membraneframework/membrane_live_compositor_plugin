ExUnit.start()

defmodule Membrane.VideoCompositor.ComposingTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline

  test "Checks composition and raw video pipeline" do
    in_path = "./test/fixtures/input_10s_720p_1fps.raw"
    out_path = "./test/fixtures/output_10s_1280x1440_1fps.raw"
    composed_video_path = "./test/fixtures/composed_video_10s_1280x1440_1fps.raw"

    video_caps = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :nx

    options = %{
      paths: %{
        first_raw_video_path: in_path,
        second_raw_video_path: in_path,
        output_path: out_path
      },
      caps: video_caps,
      implementation: implementation
    }

    assert {:ok, pid} =
             TestingPipeline.start_link(%TestingPipeline.Options{
               module: Membrane.VideoCompositor.PipelineRaw,
               custom_args: options
             })

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :file_sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)

    assert {:ok, out_video} = File.read(out_path)
    assert {:ok, composed_video} = File.read(composed_video_path)

    assert out_video == composed_video
  end
end
