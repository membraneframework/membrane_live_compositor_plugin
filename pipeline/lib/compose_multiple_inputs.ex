defmodule Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs do
  @moduledoc """
  Universal pipeline for testing composing of multiple videos, by placing them on corresponding `options.positions`.
  It loads multiple videos from the `options.paths.input_paths` files/src elements,
  parses them using `options.decoder`, feeds MultipleInputs.VideoCompositor, encodes result (or simply pass by as RawVideo
  if no `options.encoder` is specified) and feed `options.output_path` file/sink element.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Pipeline.Utility.NoOp

  @doc """
  def_options paths: [
                type: :map,
                spec: %{
                  input_paths: [String.t()] | [Membrane.Source],
                  output_path: Membrane.Sink.t() | Membrane.Sink
                },
                description:
                  "Paths to input/output video files or Membrane elements responsible for production/consumption"
              ],
              caps: [
                type: :struct,
                spec: RawVideo.t(),
                description:
                  "Specification of the output video, parameters of the final \"canvas\""
              ],
              compositor: [
                caps: :struct,
                spec: Membrane.Filter.t(),
                description: "Multiple Frames Compositor"
              ],
              decoder: [
                caps: :struct,
                spec: Membrane.Filter.t() | nil,
                description: "Decoder for the input buffers. Frames are passed by if `nil` given."
              ],
              encoder: [
                caps: :struct,
                spec: Membrane.Filter.t() | nil,
                description:
                  "Encoder for the output buffers. Frames are passed by if `nil` given."
              ]
  """
  @impl true
  def handle_init(options) do
    positions = options.positions

    source_children =
      for {input_path, i} <- Enum.with_index(options.paths.input_paths),
          do: {String.to_atom("source_#{i}"), get_src(input_path)}

    decoder_children =
      for {_element, i} <- Enum.with_index(source_children),
          do: {String.to_atom("decoder_#{i}"), get_decoder(options)}

    children =
      source_children ++
        decoder_children ++
        [
          compositor: options.compositor,
          encoder: get_encoder(options),
          sink: get_sink(options.paths.output_path)
        ]

    source_links =
      Enum.zip([source_children, decoder_children, positions])
      |> Enum.map(fn {{source_id, _source}, {decoder_id, _decoder}, position} ->
        link(source_id)
        |> to(decoder_id)
        |> via_in(:input, options: [position: position])
        |> to(:compositor)
      end)

    links =
      source_links ++
        [
          link(:compositor) |> to(:encoder) |> to(:sink)
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
    Map.get(options, :encoder) || NoOp
  end

  defp get_decoder(options) do
    Map.get(options, :decoder) || NoOp
  end

  @impl true
  def handle_element_end_of_stream({:sink, :input}, _context, state) do
    {{:ok, [playback: :terminating]}, state}
  end

  @impl true
  def handle_element_end_of_stream({_pad, _src}, _context, state) do
    {:ok, state}
  end
end
