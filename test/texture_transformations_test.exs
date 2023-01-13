defmodule Membrane.VideoCompositor.Test.TextureTransformations do
  @moduledoc false
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}
  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.Test.Support.Pipeline.Raw, as: PipelineRaw
  alias Membrane.VideoCompositor.Test.Support.Utils
  alias Membrane.VideoCompositor.VideoTransformations

  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.{
    CornersRounding,
    Cropping
  }

  @video_caps %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @duration 1
  @sub_dir_name "short_videos"

  @crop %Cropping{
    crop_top_left_corner: {0.5, 0.5},
    crop_size: {0.5, 0.5}
  }
  @corners_round %CornersRounding{
    border_radius: 100
  }
  @transformations %VideoTransformations{
    texture_transformations: [@crop, @corners_round]
  }

  describe "Checks corners rounding and cropping" do
    @describetag :tmp_dir

    # Because of differences in linux and mac hardware, we need to compere
    # rendered images to different references.
    @tag linux: true
    test "1 frame 720p raw linux", %{tmp_dir: tmp_dir} do
      test_transformations(tmp_dir, "linux")
    end

    @tag mac: true
    test "1 frame 720p raw mac", %{tmp_dir: tmp_dir} do
      test_transformations(tmp_dir, "mac")
    end
  end

  @spec test_transformations(binary(), String.t()) ::
          nil
  defp test_transformations(tmp_dir, render_environment) do
    {input_path, _output_path, _reference_path} =
      Utils.prepare_testing_video(
        @video_caps,
        @duration,
        "raw",
        tmp_dir,
        @sub_dir_name
      )

    out_caps = %RawVideo{
      @video_caps
      | width: @video_caps.width * 2,
        height: @video_caps.height * 2
    }

    output_path =
      Path.join(
        tmp_dir,
        "out_#{@duration}s_#{out_caps.width}x#{out_caps.height}_#{div(elem(out_caps.framerate, 0), elem(out_caps.framerate, 1))}fps.raw"
      )

    reference_path =
      case String.to_atom(render_environment) do
        :linux ->
          "test/fixtures/texture_transformations/ref_linux_cropping_and_corners_rounding.yuv"

        :mac ->
          "test/fixtures/texture_transformations/ref_mac_cropping_and_corners_rounding.yuv"
      end

    positions = [
      {0, 0},
      {@video_caps.width, 0},
      {0, @video_caps.height},
      {@video_caps.width, @video_caps.height}
    ]

    background_video = %InputStream{
      placement: %BaseVideoPlacement{
        position: {0, 0},
        size: {@video_caps.width * 2, @video_caps.height * 2}
      },
      transformations: %VideoTransformations{
        texture_transformations: []
      },
      caps: @video_caps,
      input: input_path
    }

    transformed_videos =
      for(
        pos <- positions,
        do: %InputStream{
          placement: %BaseVideoPlacement{
            position: pos,
            size: {@video_caps.width, @video_caps.height},
            z_value: 0.5
          },
          transformations: @transformations,
          caps: @video_caps,
          input: input_path
        }
      )

    middle_video = %InputStream{
      placement: %BaseVideoPlacement{
        position: {-@video_caps.width, -@video_caps.height},
        size: {@video_caps.width * 2, @video_caps.height * 2},
        z_value: 0.2
      },
      transformations: @transformations,
      caps: @video_caps,
      input: input_path
    }

    options = %Options{
      inputs: transformed_videos ++ [middle_video] ++ [background_video],
      output: output_path,
      caps: out_caps
    }

    assert {:ok, pid} = TestingPipeline.start_link(module: PipelineRaw, custom_args: options)

    assert_pipeline_playback_changed(pid, _, :playing)

    assert_end_of_stream(pid, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pid, blocking?: true)

    assert Utils.compare_contents_with_error(output_path, reference_path)
  end
end
