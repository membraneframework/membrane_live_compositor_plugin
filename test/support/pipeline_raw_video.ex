defmodule Membrane.VideoCompositor.PipelineRaw do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_h264_video_path: String.t(),
        second_h264_video_path: String.t(),
        output_path: String.t()
      },
      caps: RawVideo,
      implementation: :ffmpeg | :opengl | :nx
  })
  """
  @impl true
  def handle_init(options) do
    caps = options.caps

    parser = %Membrane.RawVideo.Parser{
      framerate: caps.framerate,
      width: caps.width,
      height: caps.height,
      pixel_format: caps.pixel_format
    }

    options = Map.put(options, :decoder, parser)

    Membrane.VideoCompositor.Demo.PipelineTemplate.handle_init(options)
  end

  @impl true
  def handle_element_end_of_stream({pad, ref}, context, state) do
    Membrane.VideoCompositor.Demo.PipelineTemplate.handle_element_end_of_stream(
      {pad, ref},
      context,
      state
    )
  end
end
