defmodule Membrane.VideoCompositor.TransformationsTest do
  @moduledoc false
  @behaviour Membrane.VideoCompositor.Handler

  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing.Pipeline, as: TestingPipeline
  alias Membrane.VideoCompositor.{BaseVideoPlacement, Scene, VideoConfig}
  alias Membrane.VideoCompositor.Handler.Inputs.InputProperties
  alias Membrane.VideoCompositor.Support.Pipeline.{InputStream, Options}
  alias Membrane.VideoCompositor.Support.Pipeline.Raw, as: PipelineRaw
  alias Membrane.VideoCompositor.Support.Utils

  alias Membrane.VideoCompositor.Transformations.{
    CornersRounding,
    Cropping
  }

  @video_stream_format %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @duration 1
  @sub_dir_name "short_videos"

  @reference_path "test/fixtures/texture_transformations/ref_cropping_and_corners_rounding.yuv"

  @video_stream_format %RawVideo{
    width: 1280,
    height: 720,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @crop %Cropping{
    crop_top_left_corner: {0.5, 0.5},
    crop_size: {0.5, 0.5}
  }

  @corners_round %CornersRounding{
    border_radius: 100
  }

  @transformations [@crop, @corners_round]

  @impl Membrane.VideoCompositor.Handler
  def handle_init(_options) do
    %{
      :background => %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {0, 0},
          size: {@video_stream_format.width * 2, @video_stream_format.height * 2}
        }
      },
      :middle => %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {-@video_stream_format.width, -@video_stream_format.height},
          size: {@video_stream_format.width * 2, @video_stream_format.height * 2},
          z_value: 0.2
        },
        transformations: @transformations
      },
      0 => %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {0, 0},
          size: {@video_stream_format.width, @video_stream_format.height},
          z_value: 0.5
        },
        transformations: @transformations
      },
      1 => %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {@video_stream_format.width, 0},
          size: {@video_stream_format.width, @video_stream_format.height},
          z_value: 0.5
        },
        transformations: @transformations
      },
      2 => %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {0, @video_stream_format.height},
          size: {@video_stream_format.width, @video_stream_format.height},
          z_value: 0.5
        },
        transformations: @transformations
      },
      3 => %VideoConfig{
        placement: %BaseVideoPlacement{
          position: {@video_stream_format.width, @video_stream_format.height},
          size: {@video_stream_format.width, @video_stream_format.height},
          z_value: 0.5
        },
        transformations: @transformations
      }
    }
  end

  @impl Membrane.VideoCompositor.Handler
  def handle_inputs_change(inputs, _ctx, state) do
    inputs
    |> Enum.map(fn {pad, %InputProperties{metadata: metadata}} ->
      {pad, Map.fetch!(state, metadata)}
    end)
    |> Enum.into(%{})
    |> then(fn video_configs -> {%Scene{video_configs: video_configs}, state} end)
  end

  @impl Membrane.VideoCompositor.Handler
  def handle_info(_msg, _ctx, state) do
    state
  end

  describe "Checks corners rounding and cropping" do
    @describetag :tmp_dir
    test "1 frame 720p raw", %{tmp_dir: tmp_dir} do
      test_transformations(tmp_dir)
    end
  end

  @spec test_transformations(binary()) :: nil
  defp test_transformations(tmp_dir) do
    {input_path, _output_path, _reference_path} =
      Utils.prepare_testing_video(
        @video_stream_format,
        @duration,
        "raw",
        tmp_dir,
        @sub_dir_name
      )

    out_stream_format = %RawVideo{
      @video_stream_format
      | width: @video_stream_format.width * 2,
        height: @video_stream_format.height * 2
    }

    output_path =
      Path.join(
        tmp_dir,
        "out_#{@duration}s_#{out_stream_format.width}x#{out_stream_format.height}_#{div(elem(out_stream_format.framerate, 0), elem(out_stream_format.framerate, 1))}fps.raw"
      )

    background_video = %InputStream{
      stream_format: @video_stream_format,
      input: input_path,
      metadata: :background
    }

    middle_video = %InputStream{
      input: input_path,
      stream_format: @video_stream_format,
      metadata: :middle
    }

    transformed_videos =
      Enum.map(0..3, fn i ->
        %InputStream{input: input_path, stream_format: @video_stream_format, metadata: i}
      end)

    options = %Options{
      inputs: transformed_videos ++ [middle_video] ++ [background_video],
      output: output_path,
      output_stream_format: out_stream_format,
      handler: __MODULE__
    }

    pipeline = TestingPipeline.start_link_supervised!(module: PipelineRaw, custom_args: options)
    assert_pipeline_play(pipeline)
    assert_end_of_stream(pipeline, :sink, :input, 1_000_000)
    TestingPipeline.terminate(pipeline, blocking?: true)

    assert Utils.compare_contents_with_error(output_path, @reference_path)
  end
end
