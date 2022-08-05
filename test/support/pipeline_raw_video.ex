defmodule Membrane.VideoCompositor.PipelineRaw do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_raw_video_path: String.t(),
        second_raw_video_path: String.t(),
        output_path: String.t()
      },
      caps: RawVideo,
      implementation: :ffmpeg | :opengl | :nx,
      return_pid: pid()
  })
  """
  @impl true
  def handle_init(options) do
    parser = %Membrane.RawVideo.Parser{
      framerate: options.caps.framerate,
      width: options.caps.width,
      height: options.caps.height,
      pixel_format: options.caps.pixel_format
    }

    children = %{
      file_src_1: %Membrane.File.Source{location: options.paths.first_raw_video_path},
      file_src_2: %Membrane.File.Source{location: options.paths.second_raw_video_path},
      parser_1: parser,
      parser_2: parser,
      compositor: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      file_sink: %Membrane.File.Sink{location: options.paths.output_path}
    }

    links = [
      link(:file_src_1)
      |> to(:parser_1)
      |> via_in(:first_input)
      |> to(:compositor),
      link(:file_src_2)
      |> to(:parser_2)
      |> via_in(:second_input)
      |> to(:compositor)
      |> to(:file_sink)
    ]

    {{:ok, [spec: %ParentSpec{children: children, links: links}, playback: :playing]},
     %{return_pid: options.return_pid}}
  end

  @impl true
  def handle_element_end_of_stream({:file_sink, :input}, _context, %{return_pid: pid} = state) do
    Membrane.Logger.bare_log(:info, "file_sink send EOS")
    send(pid, :finished)
    {:ok, state}
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
