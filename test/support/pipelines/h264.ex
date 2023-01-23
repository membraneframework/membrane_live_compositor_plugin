defmodule Membrane.VideoCompositor.Test.Support.Pipeline.H264 do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Pipeline.Utils.Options

  @impl true
  def handle_init(ctx, options) do
    decoder = %Membrane.VideoCompositor.Test.Support.Pipeline.H264.ParserDecoder{
      framerate: options.stream_format.framerate
    }

    encoder = Membrane.H264.FFmpeg.Encoder

    options = %Options{
      options
      | decoder: decoder,
        encoder: encoder,
        compositor: %Membrane.VideoCompositor{
          stream_format: options.stream_format
        }
    }

    Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs.handle_init(ctx, options)
  end

  @impl true
  defdelegate handle_element_end_of_stream(pad, ref, context, state),
    to: Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs
end
