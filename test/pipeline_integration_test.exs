defmodule Membrane.VideoCompositor.Test.Pipeline do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Implementations
  alias Membrane.VideoCompositor.Test.Support.Pipeline.H264, as: PipelineH264
  alias Membrane.VideoCompositor.Test.Support.Pipeline.PacketLoss, as: PipelinePacketLoss
  alias Membrane.VideoCompositor.Test.Support.Utility, as: TestingUtility

  @implementation Implementations.get_all_implementations()

  @hd_video %RawVideo{
    width: 2 * 1280,
    height: 2 * 720,
    framerate: {30, 1},
    pixel_format: :I420,
    aligned: true
  }

  @full_hd_video %RawVideo{
    width: 2 * 1920,
    height: 2 * 1080,
    framerate: {30, 1},
    pixel_format: :I420,
    aligned: true
  }

  Enum.map(@implementation, fn implementation ->
    describe "Checks h264 #{implementation} pipeline on" do
      @describetag :tmp_dir

      @tag implementation
      test "2s 720p 30fps video", %{tmp_dir: tmp_dir} do
        test_h264_pipeline(@hd_video, 2, unquote(implementation), "short_videos", tmp_dir)
      end

      @tag implementation
      test "1s 1080p 30fps video", %{tmp_dir: tmp_dir} do
        test_h264_pipeline(@full_hd_video, 1, unquote(implementation), "short_videos", tmp_dir)
      end

      @tag long: true
      test "30s 720p 30fps video", %{tmp_dir: tmp_dir} do
        test_h264_pipeline(@hd_video, 30, unquote(implementation), "long_videos", tmp_dir)
      end

      @tag long: true, timeout: 100_000
      test "60s 1080p 30fps video", %{tmp_dir: tmp_dir} do
        test_h264_pipeline(@full_hd_video, 30, unquote(implementation), "long_videos", tmp_dir)
      end
    end
  end)

  defp test_h264_pipeline(video_caps, duration, implementation, sub_dir_name, tmp_dir) do
    alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
    alias Membrane.VideoCompositor.Pipeline.Utility.Options

    {input_path, output_path, _ref_file_name} =
      TestingUtility.prepare_testing_video(video_caps, duration, "h264", tmp_dir, sub_dir_name)

    positions = [
      {0, 0},
      {div(video_caps.width, 2), 0},
      {0, div(video_caps.height, 2)},
      {div(video_caps.width, 2), div(video_caps.height, 2)}
    ]

    inputs =
      for pos <- positions,
          do: %InputStream{
            position: pos,
            caps: video_caps,
            input: input_path
          }

    out_caps = %RawVideo{video_caps | width: video_caps.width * 2, height: video_caps.height * 2}

    options = %Options{
      inputs: inputs,
      output: output_path,
      caps: out_caps,
      implementation: implementation
    }

    assert {:ok, pid} = TestingPipeline.start_link(module: PipelineH264, custom_args: options)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)
  end

  Enum.map(@implementation, fn implementation ->
    describe "Checks packet loss #{implementation} pipeline on" do
      @describetag :tmp_dir

      @tag implementation
      test "2s 720p 30fps video", %{tmp_dir: tmp_dir} do
        test_h264_pipeline_with_packet_loss(
          @hd_video,
          2,
          unquote(implementation),
          "short_videos",
          tmp_dir
        )
      end

      @tag implementation
      test "1s 1080p 30fps video", %{tmp_dir: tmp_dir} do
        test_h264_pipeline_with_packet_loss(
          @full_hd_video,
          1,
          unquote(implementation),
          "short_videos",
          tmp_dir
        )
      end
    end
  end)

  defp test_h264_pipeline_with_packet_loss(
         video_caps,
         duration,
         implementation,
         sub_dir_name,
         tmp_dir
       ) do
    alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
    alias Membrane.VideoCompositor.Pipeline.Utility.Options

    {input_path, output_path, _ref_file_name} =
      TestingUtility.prepare_testing_video(video_caps, duration, "h264", tmp_dir, sub_dir_name)

    positions = [
      {0, 0},
      {div(video_caps.width, 2), 0},
      {0, div(video_caps.height, 2)},
      {div(video_caps.width, 2), div(video_caps.height, 2)}
    ]

    inputs =
      for pos <- positions,
          do: %InputStream{
            position: pos,
            caps: video_caps,
            input: input_path
          }

    out_caps = %RawVideo{video_caps | width: video_caps.width * 2, height: video_caps.height * 2}

    options = %Options{
      inputs: inputs,
      output: output_path,
      caps: out_caps,
      implementation: implementation
    }

    assert {:ok, pid} =
             TestingPipeline.start_link(module: PipelinePacketLoss, custom_args: options)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)
  end
end
