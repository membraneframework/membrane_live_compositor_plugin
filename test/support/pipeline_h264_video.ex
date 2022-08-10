defmodule Membrane.VideoCompositor.PipelineH264 do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_video_path: String.t(),
        second_video_path: String.t(),
        output_path: String.t()
      },
      caps: RawVideo,
      implementation: :ffmpeg | :opengl | :nx
  })
  """
  @impl true
  def handle_init(options) do
    decoder = Membrane.VideoCompositor.Demo.H264.InputParser
    encoder = Membrane.H264.FFmpeg.Encoder

    options = Map.put(options, :decoder, decoder)
    options = Map.put_new(options, :encoder, encoder)

    Membrane.VideoCompositor.Demo.PipelineTemplate.handle_init(options)
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
