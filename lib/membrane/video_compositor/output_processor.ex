defmodule Membrane.LiveCompositor.OutputProcessor do
  @moduledoc false
  # Forwards buffers and send specified output stream format.

  use Membrane.Filter

  def_options output_stream_format: [
                spec: Membrane.H264.t()
              ]

  def_input_pad :input,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    flow_control: :auto

  def_output_pad :output,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    flow_control: :auto

  @impl true
  def handle_init(_ctx, opt) do
    {[], %{output_stream_format: opt.output_stream_format}}
  end

  @impl true
  def handle_buffer(_pad, buffer, ctx, state) do
    stream_format_action =
      if ctx.pads.output.stream_format == nil do
        [stream_format: {:output, state.output_stream_format}]
      else
        []
      end

    {stream_format_action ++ [buffer: {:output, buffer}], state}
  end

  @impl true
  def handle_stream_format(_pad, _stream_format, _ctx, state) do
    {[], state}
  end
end
