defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  def handle_init(options) do
    # [options | _] = options

    children = %{
      first_file: %Membrane.File.Source{location: options.first_raw_video_path},
      second_file: %Membrane.File.Source{location: options.second_raw_video_path},
      first_parser: %Membrane.RawVideo.Parser{
        framerate: {options.video_framerate, 1},
        width: options.video_width,
        height: options.video_height,
        pixel_format: :I420
      },
      second_parser: %Membrane.RawVideo.Parser{
        framerate: {options.video_framerate, 1},
        width: options.video_width,
        height: options.video_height,
        pixel_format: :I420
      },
      video_composer: %Membrane.VideoCompositor{
        implementation: options.implementation,
        video_width: options.video_width,
        video_height: options.video_height
      },
      encoder: Membrane.H264.FFmpeg.Encoder,
      file_sink: %Membrane.File.Sink{location: options.output_path}
      # sink: %Membrane.VideoCompositor.Sink{location: options.output_path}
    }

    links = [
      link(:first_file) |> to(:first_parser),
      link(:second_file) |> to(:second_parser),
      link(:first_parser) |> via_in(:first_input) |> to(:video_composer),
      link(:second_parser) |> via_in(:second_input) |> to(:video_composer),
      link(:video_composer) |> to(:encoder) |> to(:file_sink)
      # link(:video_composer) |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end

  def handle_element_end_of_stream({:file_sink, :input}, _cts, state) do
    {{:ok, playback: :terminating}, state}
  end

  def handle_element_end_of_stream(_element, _cts, state) do
    {:ok, state}
  end
end
