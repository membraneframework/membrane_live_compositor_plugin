defmodule Membrane.VideoCompositor.Test.Pipeline.H264.ComposeTwoInputs do
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
    decoder = Membrane.VideoCompositor.Test.Pipeline.H264.TwoInputsParser
    encoder = Membrane.H264.FFmpeg.Encoder

    options = Map.put(options, :decoder, decoder)
    options = Map.put_new(options, :encoder, encoder)

    options =
      Map.put_new(options, :compositor, %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      })

    Membrane.VideoCompositor.Pipeline.ComposeTwoInputs.handle_init(options)
  end

  @impl true
  def handle_element_end_of_stream({:file_sink, :input}, _context, state) do
    {{:ok, [playback: :terminating]}, state}
  end

  @impl true
  def handle_element_end_of_stream(_pad, _context, state) do
    {:ok, state}
  end
end
