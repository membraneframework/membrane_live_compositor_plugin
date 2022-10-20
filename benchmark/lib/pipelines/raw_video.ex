defmodule Membrane.VideoCompositor.Test.Support.Pipeline.Raw do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """
  use Membrane.Pipeline

  alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
  alias Membrane.VideoCompositor.Pipeline.Utility.Options

  @impl true
  def handle_init(%Options{} = options) do
    [%InputStream{caps: in_caps} | _tail] = options.inputs

    parser = %Membrane.RawVideo.Parser{
      framerate: in_caps.framerate,
      width: in_caps.width,
      height: in_caps.height,
      pixel_format: in_caps.pixel_format
    }

    options = %Options{
      options
      | decoder: parser,
        compositor: %Membrane.VideoCompositor{
          implementation: options.implementation,
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
