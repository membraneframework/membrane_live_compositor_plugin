defmodule Membrane.VideoCompositor.Test.Pipeline.H264.MultipleInputs do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """

  use Membrane.Pipeline

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

    Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs.handle_init(options)
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
