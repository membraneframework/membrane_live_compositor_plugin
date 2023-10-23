defmodule Membrane.VideoCompositor.OutputProcessor do
  @moduledoc false

  use Membrane.Filter

  def_options output_stream_format: [
                spec: Membrane.H264.t(),
                description: "VideoCompositor output stream format"
              ]

  def_input_pad :input,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :always,
    flow_control: :auto

  def_output_pad :output,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :always,
    flow_control: :auto

  @impl true
  def handle_init(_ctx, opt) do
    {[], %{first_buffer?: true, output_stream_format: opt.output_stream_format}}
  end

  @impl true
  def handle_buffer(_pad, buffer, _ctx, state) do
    stream_format_action =
      if state.first_buffer? do
        [stream_format: {:output, state.output_stream_format}]
      else
        []
      end

    {stream_format_action ++ [buffer: {:output, buffer}], %{state | first_buffer?: false}}
  end

  @impl true
  def handle_stream_format(_pad, _stream_format, _ctx, state) do
    {[], state}
  end
end
