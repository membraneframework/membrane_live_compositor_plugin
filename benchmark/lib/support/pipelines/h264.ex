defmodule Membrane.VideoCompositor.Benchmark.Support.Pipeline.H264 do
  @moduledoc """
  Pipeline for demo composing of many videos.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Pipeline.Utility.Options

  @impl true
  def handle_init(options) do
    decoder = Membrane.VideoCompositor.Benchmark.Support.Pipeline.H264.ParserDecoder
    encoder = Membrane.H264.FFmpeg.Encoder

    options = %Options{
      options
      | decoder: decoder,
        encoder: encoder,
        compositor: %Membrane.VideoCompositor{
          caps: options.caps
        }
    }

    Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs.handle_init(options)
  end

  @impl true
  def handle_element_end_of_stream({pad, ref}, context, state) do
    Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs.handle_element_end_of_stream(
      {pad, ref},
      context,
      state
    )
  end
end
