defmodule Membrane.VideoCompositor.Test.Support.Pipeline.PacketLoss do
  @moduledoc """
  Pipeline for testing composing of many videos.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Pipeline.Utility.Options

  @impl true
  def handle_init(options) do
    decoder = %Membrane.VideoCompositor.Test.Support.Pipeline.H264.ParserDecoder{
      framerate: options.caps.framerate
    }

    encoder = Membrane.H264.FFmpeg.Encoder

    {frames, seconds} = options.caps.framerate
    spf = seconds / frames

    bad_connection_emulator = %Membrane.VideoCompositor.Test.Support.BadConnectionEmulator{
      delay_interval: {spf, 2 * spf}
    }

    options = %Options{
      options
      | decoder: decoder,
        encoder: encoder,
        input_filter: bad_connection_emulator,
        compositor: %Membrane.VideoCompositor{
          caps: options.caps,
          real_time: true
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
