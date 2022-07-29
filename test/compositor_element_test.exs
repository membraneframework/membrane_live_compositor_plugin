defmodule Membrane.VideoCompositor.DemoPipelineTest do
  use ExUnit.Case, async: true

  import Membrane.Testing.Assertions

  alias Membrane.Testing.Pipeline
  alias Membrane.RawVideo

  test "Simple compositor module for joining two 1280x720 videos" do
    video = %RawVideo{
      width: 1280,
      height: 720,
      framerate: 30,
      pixel_format: :I420,
      aligned: nil
    }

    implementation = :nx
    duration = 30

    in_path = "/test/fixtures/input_30s_720p.h264"
    out_path = "/test/fixtures/output_30s_1280x1440.h264"

    options = %{
      paths: %{
        first_h264_video_path: in_path,
        second_h264_video_path: in_path,
        output_path: out_path
      }
    }



  end
end
