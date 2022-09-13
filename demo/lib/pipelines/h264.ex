defmodule Membrane.VideoCompositor.Test.Support.Pipeline.H264 do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """

  use Membrane.Pipeline

  @impl true
  def handle_init(options) do
    decoder = Membrane.VideoCompositor.Test.Support.Pipeline.H264.ParserDecoder
    encoder = Membrane.H264.FFmpeg.Encoder

    options = Map.put(options, :decoder, decoder)
    options = Map.put_new(options, :encoder, encoder)

    options =
      Map.put_new(options, :compositor, %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      })

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
