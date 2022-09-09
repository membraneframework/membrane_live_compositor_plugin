defmodule Membrane.VideoCompositor.Pipeline.ComposeMultipleInputs do
  @moduledoc """
  Universal pipeline for testing composing of multiple videos, by placing them on corresponding `options.positions`.
  It loads multiple videos from the `options.inputs.input` files/src elements,
  parses them using `options.decoder`, feeds MultipleInputs.VideoCompositor, encodes result (or simply pass by as RawVideo
  if no `options.encoder` is specified or set to nil) and feed `options.output` file/sink element.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Pipeline.Utility.NoOp
  alias Membrane.VideoCompositor.Pipeline.Utility.InputStream

  @doc """
  def_options inputs: [
                type: :list
                spec: [InputStream.t()],
                description: "Specifications of the input video sources"
              ],
              output: [
                type: :struct,
                spec: String.t() | Membrane.Sink.t() | Membrane.Sink,
                description: "Specifications of the sink element or path to the output video file"
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
    source_children =
      for {%InputStream{input: input}, i} <- Enum.with_index(options.inputs),
          do: {String.to_atom("source_#{i}"), get_src(input)}

    decoder_children =
      for {_element, i} <- Enum.with_index(source_children),
          do: {String.to_atom("decoder_#{i}"), get_decoder(options)}

    children =
      source_children ++
        decoder_children ++
        [
          compositor: options.compositor,
          encoder: get_encoder(options),
          sink: get_sink(options.output)
        ]

    source_links =
      Enum.zip([source_children, decoder_children, options.inputs])
      |> Enum.map(fn {{source_id, _source}, {decoder_id, _decoder},
                      %InputStream{position: position}} ->
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
