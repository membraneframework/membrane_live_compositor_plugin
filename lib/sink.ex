defmodule Membrane.VideoCompositor.Sink do
  @moduledoc """
  Module responsible for writing incomming buffers to location passed in options.
  """
  use Membrane.Sink
  alias Membrane.RawVideo

  def_input_pad(:input,
    demand_unit: :buffers,
    caps: {RawVideo, pixel_format: :I420}
  )

  def handle_init(options) do
    {:ok, %{location: options.location}}
  end

  def handle_write(:input, buffer, _ctx, state) do
    File.write!(state.location, buffer.payload)
    {:ok, state}
  end
end
