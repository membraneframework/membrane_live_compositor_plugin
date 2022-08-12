defmodule Membrane.VideoCompositor.Demo.Helpers.NoOp do
  @moduledoc """
  Simple pass by Membrane element.It should have no side effects on the pipeline.
  """
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
  Universal pipeline for testing simple composing of two videos, by placing one above the other.
  It loads two videos from the `options.first_video_path` and `options.second_video_path` files/src elements,
  parses them using `options.decoder`, feeds VideoCompositor, encodes result (or simply pass by as RawVideo
  if no `options.encoder` is specified) and feed `options.output_path` file/sink element.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
    paths: %{
        first_video_path: String.t() | Membrane.Source,
        second_video_path: String.t() | Membrane.Source,
        output_path: Membrane.Sink.t() | Membrane.Sink
      },
      caps: RawVideo.t(),
      implementation: :ffmpeg | :opengl | :nx,
      decoder: Membrane.Filter.t() | nil,
      encoder: Membrane.Filter.t() | nil
  })
  """
  @impl true
  def handle_init(options) do
    children = %{
      src_1: get_src(options.paths.first_video_path),
      src_2: get_src(options.paths.second_video_path),
      decoder_1: get_decoder(options),
      decoder_2: get_decoder(options),
      compositor: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      encoder: get_encoder(options),
      sink: get_sink(options.paths.output_path)
    }

    links = [
      link(:src_1)
      |> to(:decoder_1)
      |> via_in(:first_input)
      |> to(:compositor),
      link(:src_2)
      |> to(:decoder_2)
      |> via_in(:second_input)
      |> to(:compositor),
      link(:compositor)
      |> to(:encoder)
      |> to(:sink)
    ]

    {{:ok, [spec: %ParentSpec{children: children, links: links}, playback: :playing]}, %{}}
  end

  defp get_src(input_path) when is_binary(input_path) do
    %Membrane.File.Source{location: input_path}
  end

  defp get_src(src) when not is_nil(src) do
    src
  end

  defp get_sink(output_path) when is_binary(output_path) do
    %Membrane.File.Sink{location: output_path}
  end

  defp get_sink(sink) when not is_nil(sink) do
    sink
  end

  defp get_encoder(options) do
    Map.get(options, :encoder) || Membrane.VideoCompositor.Demo.Helpers.NoOp
  end

  defp get_decoder(options) do
    Map.get(options, :decoder) || Membrane.VideoCompositor.Demo.Helpers.NoOp
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
