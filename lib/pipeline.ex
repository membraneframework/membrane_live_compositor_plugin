defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  Videos spec: framerate 30, resolution: 1280x720, pixel format: I420, encoding: raw video
  """

  use Membrane.Pipeline

  # options = [path_to_raw_video, output_path]
  def handle_init(options) do
    # extract videos paths
    [path_to_first_raw_video | [output_path | _]] = options  # unwrap options

    children = %{
      source: %Membrane.File.Source{location: path_to_first_raw_video},

      parser: %Membrane.RawVideo.Parser{framerate: {30, 1}, width: 1280, height: 720, pixel_format: :I420},

      composer: Membrane.VideoCompositor.Merger,

      encoder: Membrane.H264.FFmpeg.Encoder,
      sink: %Membrane.File.Sink{location: output_path}
    }

    links = [
      link(:source)
      |> to(:parser)
      |> to(:composer)
      |> to(:encoder)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end

  def handle_element_end_of_stream(_element, _cts, state) do
    {:ok, state}
  end
end
