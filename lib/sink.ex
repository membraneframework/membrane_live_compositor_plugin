defmodule Membrane.VideoCompositor.Sink do
  @moduledoc """
  Module responsible for writing incoming buffers to location passed in options.
  """
  use Membrane.Sink
  alias Membrane.RawVideo

  def_options location: [
                type: :string,
                description: "Location of output file"
              ]

  def_input_pad(:input,
    demand_unit: :buffers,
    caps: {RawVideo, pixel_format: :I420}
  )

  @impl true
  def handle_init(options) do
    {:ok, %{location: options.location}}
  end

  @impl true
  def handle_write(:input, buffer, _ctx, state) do
    IO.binwrite(state.location, buffer.payload)
    {:ok, state}
  end
end
