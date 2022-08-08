defmodule Membrane.VideoCompositor.Demo.Helpers.NoOp do
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any, demand_mode: :auto
  def_output_pad :output, demand_unit: :buffers, caps: :any, demand_mode: :auto

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
    decoder = options.decoder
    sink = get_sink(options)
    encoder = get_encoder(options)

    children = %{
      file_src_1: %Membrane.File.Source{location: options.paths.first_video_path},
      file_src_2: %Membrane.File.Source{location: options.paths.second_video_path},
      decoder_1: decoder,
      decoder_2: decoder,
      compositor: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      encoder: encoder,
      sink: sink
    }

    links = [
      link(:file_src_1)
      |> to(:decoder_1)
      |> via_in(:first_input)
      |> to(:compositor),
      link(:file_src_2)
      |> to(:decoder_2)
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

  defp get_encoder(options) do
    Map.get(options, :encoder) || Membrane.VideoCompositor.Demo.Helpers.NoOp
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
