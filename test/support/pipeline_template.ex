defmodule Membrane.VideoCompositor.Demo.Helpers.NoOp do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any
  def_input_pad :output, demand_unit: :buffers, caps: :any

  @impl true
  def handle_init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, buffer: {:output, buffer}}, state}
  end
end

defmodule Membrane.VideoCompositor.Demo.PipelineTemplate do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_video_path: String.t(),
        second_video_path: String.t(),
        decoder: Membrane.Filter.t(),
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
    encoder = get_decoder(options)

    children = %{
      file_src_1: %Membrane.File.Source{location: options.paths.first_video_path},
      file_src_2: %Membrane.File.Source{location: options.paths.second_video_path},
      parser_1: parser,
      parser_2: parser,
      compositor: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      encoder: encoder,
      sink: sink
    }

    # parser = Membrane.H264.FFmpeg.Parser
    # decoder = Membrane.H264.FFmpeg.Decoder

    links = [
      link(:file_src_1)
      |> to(:parser_1)
      |> via_in(:first_input)
      |> to(:compositor),
      link(:file_src_2)
      |> to(:parser_2)
      |> via_in(:second_input)
      |> to(:compositor),
      link(:compositor)
      |> to(:encoder)
      |> to(:sink)
    ]

    {{:ok, [spec: %ParentSpec{children: children, links: links}, playback: :playing]}, %{}}
  end

  defp get_sink(%{sink: sink} = _options) when not is_nil(sink) do
    sink
  end

  defp get_sink(%{paths: %{output_path: output_path}} = _options) do
    %Membrane.File.Sink{location: output_path}
  end

  defp get_decoder(options) do
    Map.get(options, :encoder) || Membrane.VideoCompositor.Demo.Helpers.NoOp
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
