ExUnit.start()

defmodule Membrane.VideoCompositor.DemoPipelineTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.RawVideo

  test "Simple compositor module for joining two 1280x720 videos" do

    in_path = "./test/fixtures/input_30s_720p.h264"
    out_path = "./test/fixtures/output_30s_1280x1440.h264"

    video_caps = %RawVideo{
      width: 1280,
      height: 720,
      framerate: 30,
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :nx
    duration = 30

    options = %{
      paths: %{
        first_h264_video_path: in_path,
        second_h264_video_path: in_path,
        output_path: out_path
      },
      caps: video_caps,
      implementation: implementation
    }

    assert {:ok, pid} = TestingPipeline.start_link(%TestingPipeline.Options{
      module: Membrane.VideoCompositor.PipelineH264,
      custom_args: options
    })

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :file_sink, :input, 100_000)
    TestingPipeline.terminate(pid, blocking?: true)
  end
end
