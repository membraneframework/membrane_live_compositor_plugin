defmodule Membrane.VideoCompositor.Support.Pipeline.ComposeMultipleInputs do
  @moduledoc """
  Universal pipeline for testing composing of multiple videos, by placing them on corresponding `options.positions`.
  It loads multiple videos from the `options.inputs.input` files/src elements,
  parses them using `options.decoder`, feeds MultipleInputs.VideoCompositor, encodes result (or simply pass by as RawVideo
  if no `options.encoder` is specified or set to nil) and feed `options.output` file/sink element.
  """

  use Membrane.Pipeline
  alias Membrane.VideoCompositor.Support.Pipeline.{InputStream, Options}

  @impl true
  def handle_init(_ctx, options = %Options{}) do
    source_spec =
      Enum.with_index(options.inputs)
      |> Enum.map(fn {%InputStream{
                        input: input,
                        timestamp_offset: timestamp_offset,
                        metadata: metadata
                      }, i} ->
        source = get_src(input)
        source_name = String.to_atom("source_#{i}")

        decoder = options.decoder
        decoder_name = String.to_atom("decoder_#{i}")

        input_filter = options.input_filter
        input_filter_name = String.to_atom("input_filter_#{i}")

        child(source_name, source)
        |> then(if is_nil(decoder), do: & &1, else: &child(&1, decoder_name, decoder))
        |> then(
          if is_nil(input_filter), do: & &1, else: &child(&1, input_filter_name, input_filter)
        )
        |> via_in(:input,
          options: [
            metadata: metadata,
            timestamp_offset: timestamp_offset
          ]
        )
        |> get_child(:compositor)
      end)

    spec =
      [
        child(:compositor, options.compositor)
        |> then(if is_nil(options.encoder), do: & &1, else: &child(&1, :encoder, options.encoder))
        |> child(:sink, get_sink(options.output))
      ] ++ source_spec

    {[spec: spec, playback: :playing], %{}}
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

  @impl true
  def handle_element_end_of_stream(:sink, :input, _context, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_pad, _src, _context, state) do
    {[], state}
  end
end
