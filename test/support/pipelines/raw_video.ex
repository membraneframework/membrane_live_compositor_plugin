defmodule Membrane.VideoCompositor.Support.Pipeline.Raw do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """
  use Membrane.Pipeline

  alias Membrane.VideoCompositor.Pipeline.Utils.{InputStream, Options}

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
          stream_format: options.stream_format
        }
    }

    Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs.handle_init(ctx, options)
  end

  @impl true
  defdelegate handle_element_end_of_stream(pad, element, context, state),
    to: Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs
end
