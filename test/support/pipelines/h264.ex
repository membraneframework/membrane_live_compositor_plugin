defmodule Membrane.VideoCompositor.Support.Pipeline.H264 do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Support.Pipeline.{ComposeMultipleInputs, Options}

  @impl true
  def handle_init(ctx, options) do
    decoder = %Membrane.VideoCompositor.Support.Pipeline.H264.ParserDecoder{
      framerate: options.output_stream_format.framerate
    }

    encoder = Membrane.H264.FFmpeg.Encoder

    options = %Options{
      options
      | decoder: decoder,
        encoder: encoder,
        compositor: %Membrane.VideoCompositor{
          output_stream_format: options.output_stream_format,
          handler: options.handler
        }
    }

    ComposeMultipleInputs.handle_init(ctx, options)
  end

  @impl true
  defdelegate handle_element_end_of_stream(pad, ref, context, state),
    to: ComposeMultipleInputs
end
