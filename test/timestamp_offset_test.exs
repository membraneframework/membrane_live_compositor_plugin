defmodule Membrane.VideoCompositor.Test.TimestampOffset do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.RustStructs.VideoPlacement
  alias Membrane.VideoCompositor.Test.Support.Pipeline.H264, as: PipelineH264
  alias Membrane.VideoCompositor.Test.Support.Utils
  alias Membrane.VideoCompositor.VideoTransformations

  @hd_video %RawVideo{
    width: 1280,
    height: 720,
    framerate: {30, 1},
    pixel_format: :I420,
    aligned: true
  }

  @empty_video_transformations VideoTransformations.get_empty_video_transformations()

  describe "Checks timestamp_offset function on pipeline with" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "0s offset option", %{tmp_dir: tmp_dir} do
      test_video_offset_option(@hd_video, 0, 2, "timestamp_offset_test_videos", tmp_dir)
    end

    @tag wgpu: true
    test "2s offset option", %{tmp_dir: tmp_dir} do
      test_video_offset_option(@hd_video, 2, 2, "timestamp_offset_test_videos", tmp_dir)
    end
  end

  defp test_video_offset_option(video_caps, timestamp_offset, duration, sub_dir_name, tmp_dir) do
    options =
      prepare_pipeline_options(
        video_caps,
        timestamp_offset,
        duration,
        sub_dir_name,
        tmp_dir
      )

    assert {:ok, pid} = TestingPipeline.start_link(module: PipelineH264, custom_args: options)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)
  end

  defp prepare_pipeline_options(
         video_caps,
         timestamp_offset,
         duration,
         sub_dir_name,
         tmp_dir
       ) do
    alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}

    {input_path, _output_path, _ref_file_name} =
      Utils.prepare_testing_video(
        video_caps,
        duration,
        "h264",
        tmp_dir,
        sub_dir_name
      )

    output_path =
      Path.join(
        tmp_dir,
        "out_#{duration}s_#{video_caps.width}x#{video_caps.height}_#{div(elem(video_caps.framerate, 0), elem(video_caps.framerate, 1))}fps.raw"
      )

    inputs = [
      %InputStream{
        placement: %VideoPlacement{
          position: {0, 0},
          display_size: {video_caps.width, video_caps.height}
        },
        transformations: @empty_video_transformations,
        caps: video_caps,
        timestamp_offset: timestamp_offset,
        input: input_path
      }
    ]

    options = %Options{
      inputs: inputs,
      output: output_path,
      caps: video_caps
    }

    options
  end
end
