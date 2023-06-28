defmodule Membrane.VideoCompositor.Support.Pipeline.Raw do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """
  use Membrane.Pipeline

  alias Membrane.VideoCompositor.Support.Pipeline.{ComposeMultipleInputs, InputStream, Options}

  @impl true
  def handle_init(ctx, options) do
    [%InputStream{stream_format: in_stream_format} | _tail] = options.inputs

    parser = %Membrane.RawVideo.Parser{
      framerate: in_stream_format.framerate,
      width: in_stream_format.width,
      height: in_stream_format.height,
      pixel_format: in_stream_format.pixel_format
    }

    options = %Options{
      options
      | decoder: parser,
        compositor: %Membrane.VideoCompositor{
          output_stream_format: options.output_stream_format,
          handler: options.handler
        }
    }

    ComposeMultipleInputs.handle_init(ctx, options)
  end

  @impl true
  defdelegate handle_element_end_of_stream(pad, element, context, state),
    to: ComposeMultipleInputs
end
