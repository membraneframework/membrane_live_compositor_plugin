defmodule Membrane.VideoCompositor.Testing.Pipeline.Raw do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """

  use Membrane.Pipeline

  @impl true
  def handle_init(options) do
    in_caps = options.in_caps

    parser = %Membrane.RawVideo.Parser{
      framerate: in_caps.framerate,
      width: in_caps.width,
      height: in_caps.height,
      pixel_format: in_caps.pixel_format
    }

    options = Map.put(options, :decoder, parser)

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
