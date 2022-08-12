defmodule Membrane.VideoCompositor.ComposingTest do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Test.Pipeline.Raw, as: PipelineRaw
  alias Membrane.VideoCompositor.Test.Utility, as: TestingUtility

  @filter_description "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
  @implementations [:nx, :ffmpeg]

  @hd_video %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: nil
  }

  Enum.map(@implementations, fn implementation ->
    describe "Checks #{implementation} composition and raw video pipeline on" do
      @describetag :tmp_dir

      test "3s 720p 1fps raw video", %{tmp_dir: tmp_dir} do
        test_raw_composing(@hd_video, 3, unquote(implementation), tmp_dir, "short_videos")
      end

      @tag long: true
      test "10s 720p 1fps raw video", %{tmp_dir: tmp_dir} do
        test_raw_composing(@hd_video, 10, unquote(implementation), tmp_dir, "long_videos")
      end
    end
  end)

  @spec test_raw_composing(Membrane.RawVideo.t(), non_neg_integer(), atom, binary(), binary()) ::
          nil
  defp test_raw_composing(caps, duration, implementation, tmp_dir, sub_dir_name) do
    {input_path, output_path, reference_path} =
      TestingUtility.prepare_testing_video(caps, duration, "raw", tmp_dir, sub_dir_name)

    :ok =
      TestingUtility.generate_raw_ffmpeg_reference(
        input_path,
        caps,
        reference_path,
        @filter_description
      )

    options = %{
      paths: %{
        first_video_path: input_path,
        second_video_path: input_path,
        output_path: output_path
      },
      caps: caps,
      implementation: implementation
    }

    assert {:ok, pid} = TestingPipeline.start_link(module: PipelineRaw, custom_args: options)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)

    assert {:ok, out_video} = File.read(output_path)
    assert {:ok, composed_video} = File.read(reference_path)

    assert out_video == composed_video
  end
end
