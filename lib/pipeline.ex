defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline
  alias Membrane.RawVideo

  @impl true
  @spec handle_init(%{
          paths: %{
            first_raw_video_path: String.t(),
            second_raw_video_path: String.t(),
            output_path: String.t()
          },
          caps: RawVideo,
          implementation: :ffmpeg | :opengl | :nx
        }) :: {{:ok, any()}, map()}
  def handle_init(options) do
    children = %{
      first_file: %Membrane.File.Source{location: options.paths.first_raw_video_path},
      second_file: %Membrane.File.Source{location: options.paths.second_raw_video_path},
      first_parser: %Membrane.RawVideo.Parser{
        framerate: options.caps.framerate,
        width: options.caps.width,
        height: options.caps.height,
        pixel_format: options.caps.pixel_format
      },
      second_parser: %Membrane.RawVideo.Parser{
        framerate: options.caps.framerate,
        width: options.caps.width,
        height: options.caps.height,
        pixel_format: options.caps.pixel_format
      },
      video_composer: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      file_sink: %Membrane.File.Sink{location: options.paths.output_path}
    }

    links = [
      link(:first_file)
      |> to(:first_parser)
      |> via_in(:first_input)
      |> to(:video_composer),
      link(:second_file)
      |> to(:second_parser)
      |> via_in(:second_input)
      |> to(:video_composer)
      |> to(:file_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
