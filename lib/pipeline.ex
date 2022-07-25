defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  Videos spec: framerate 30, resolution: 1280x720, pixel format: I420, encoding: raw video
  """

  use Membrane.Pipeline

  # options = %{path_to_first_raw_video, path_to_second_raw_video, output_path, implementation}
  def handle_init(options) do
    # extract videos paths
    path_to_first_raw_video = options.path_to_first_raw_video
    path_to_second_raw_video = options.path_to_second_raw_video
    output_path = options.output_path
    implementation = options.implementation

    _video_composer_options = %{implementation: implementation}

    children = %{
      first_file: %Membrane.File.Source{location: path_to_first_raw_video},
      second_file: %Membrane.File.Source{location: path_to_second_raw_video},
      first_parser: %Membrane.RawVideo.Parser{
        framerate: {30, 1},
        width: 1280,
        height: 720,
        pixel_format: :I420
      },
      second_parser: %Membrane.RawVideo.Parser{
        framerate: {30, 1},
        width: 1280,
        height: 720,
        pixel_format: :I420
      },
      video_composer: Membrane.VideoCompositor.Compositor,
      encoder: Membrane.H264.FFmpeg.Encoder,
      file_sink: %Membrane.File.Sink{location: output_path}
    }

    links = [
      link(:first_file) |> to(:first_parser),
      link(:second_file) |> to(:second_parser),
      link(:first_parser) |> via_in(:first_input) |> to(:video_composer),
      link(:second_parser) |> via_in(:second_input) |> to(:video_composer),
      link(:video_composer) |> to(:encoder) |> to(:file_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end

  def handle_element_end_of_stream(_element, _cts, state) do
    {:ok, state}
  end
end
