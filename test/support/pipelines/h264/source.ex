defmodule Membrane.VideoCompositor.Test.Support.Pipeline.H264.Source do
  @moduledoc """
  H264 Source from video file
  """
  use Membrane.Bin

  alias Membrane.File
  alias Membrane.H264.FFmpeg.{Decoder, Parser}
  alias Membrane.RawVideo

  def_options location: [
                spec: String.t(),
                description: "Input video filename"
              ]

  def_output_pad :output,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: one_of([:I420, :I422]), aligned: true}

  @impl true
  def handle_init(opts) do
    children = %{
      source: %File.Source{location: opts.location},
      parser: Parser,
      decoder: Decoder
    }

    links = [
      link(:source) |> to(:parser) |> to(:decoder) |> to_bin_output(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end
end
