defmodule Membrane.VideoCompositor.PipelineTemplate do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_video_path: String.t(),
        second_video_path: String.t(),
        input_parser: Membrane.Filter.t(),
        sink: Membrane.Sink.t()
      },
      caps: RawVideo,
      implementation: :ffmpeg | :opengl | :nx
  })
  """
  @impl true
  def handle_init(options) do
    parser = options.input_parser
    sink = get_sink(options)

    children = %{
      file_src_1: %Membrane.File.Source{location: options.paths.first_video_path},
      file_src_2: %Membrane.File.Source{location: options.paths.second_video_path},
      parser_1: parser,
      parser_2: parser,
      compositor: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      sink: sink
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
      |> to(:sink)
    ]

    {{:ok, [spec: %ParentSpec{children: children, links: links}, playback: :playing]}, %{}}
  end

  defp get_sink(%{paths: %{output_path: output_path}} = _options) do
    %Membrane.File.Sink{location: output_path}
  end

  defp get_sink(%{sink: sink} = _options) do
    sink
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
