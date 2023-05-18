defmodule Membrane.VideoCompositor.ComposingTest do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Scene.BaseVideoPlacement
  alias Membrane.VideoCompositor.Support.Pipeline.Raw, as: PipelineRaw
  alias Membrane.VideoCompositor.Support.Utils

  @filter_description "split[b1], pad=iw:ih*2[a1], [a1][b1]overlay=0:h, split[b2], pad=iw*2:ih[a2], [a2][b2]overlay=w:0"

  @hd_video %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @empty_video_transformations Membrane.VideoCompositor.VideoTransformations.empty()

  # In this test we need to increase allowed mean square error, due to differences in
  # "rendering" between ffmpeg created ref and wgpu produced output
  @allowed_mse 2.5

  describe "Checks composition and raw video pipeline on merging four videos on 2x2 grid" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "3s 720p 1fps raw", %{tmp_dir: tmp_dir} do
      test_raw_composing(@hd_video, 3, tmp_dir, "short_videos")
    end

    @tag long_wgpu: true
    test "10s 720p 1fps raw", %{tmp_dir: tmp_dir} do
      test_raw_composing(@hd_video, 10, tmp_dir, "long_videos")
    end
  end

  @spec test_raw_composing(Membrane.RawVideo.t(), non_neg_integer(), binary(), binary()) ::
          nil
  defp test_raw_composing(video_stream_format, duration, tmp_dir, sub_dir_name) do
    alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}

    {input_path, _output_path, _reference_path} =
      Utils.prepare_testing_video(
        video_stream_format,
        duration,
        "raw",
        tmp_dir,
        sub_dir_name
      )

    out_stream_format = %RawVideo{
      video_stream_format
      | width: video_stream_format.width * 2,
        height: video_stream_format.height * 2
    }

    output_path =
      Path.join(
        tmp_dir,
        "out_#{duration}s_#{out_stream_format.width}x#{out_stream_format.height}_#{div(elem(out_stream_format.framerate, 0), elem(out_stream_format.framerate, 1))}fps.raw"
      )

    reference_path =
      Path.join(
        tmp_dir,
        "ref_#{duration}s_#{out_stream_format.width}x#{out_stream_format.height}_#{div(elem(out_stream_format.framerate, 0), elem(out_stream_format.framerate, 1))}fps.raw"
      )

    :ok =
      Utils.generate_raw_ffmpeg_reference(
        input_path,
        video_stream_format,
        reference_path,
        @filter_description
      )

    positions = [
      {0, 0},
      {video_stream_format.width, 0},
      {0, video_stream_format.height},
      {video_stream_format.width, video_stream_format.height}
    ]

    inputs =
      for(
        pos <- positions,
        do: %InputStream{
          placement: %BaseVideoPlacement{
            position: pos,
            size: {video_stream_format.width, video_stream_format.height}
          },
          transformations: @empty_video_transformations,
          stream_format: video_stream_format,
          input: input_path
        }
      )

    options = %Options{
      inputs: inputs,
      output: output_path,
      stream_format: out_stream_format
    }

    pipeline = TestingPipeline.start_link_supervised!(module: PipelineRaw, custom_args: options)
    assert_pipeline_play(pipeline)

    assert_end_of_stream(pipeline, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pipeline, blocking?: true)

    assert Utils.compare_contents_with_error(output_path, reference_path, @allowed_mse)
  end
end
