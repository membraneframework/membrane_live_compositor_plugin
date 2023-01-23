defmodule Membrane.VideoCompositor.Test.Support.Pipeline.H264.ParserDecoder do
  @moduledoc """
  Simple bin parsing and decoding H264 buffers into raw frames.
  """
  use Membrane.Bin
  alias Membrane.RawVideo

  def_options framerate: [
                spec: H264.framerate_t() | nil,
                default: nil,
                description: """
                Framerate of video stream, see `t:Membrane.H264.framerate_t/0`
                """
              ]

  def_input_pad :input, accepted_format: _any

  def_output_pad :output,
    accepted_format:
      %RawVideo{pixel_format: pix_fmt, aligned: true} when pix_fmt in [:I420, :I422]

  @impl true
  def handle_init(_ctx, opts) do
    spec =
      bin_input()
      |> child(:parser, %Membrane.H264.FFmpeg.Parser{framerate: opts.framerate})
      |> child(:decoder, Membrane.H264.FFmpeg.Decoder)
      |> bin_output()

    {[spec: spec], %{}}
  end
end
