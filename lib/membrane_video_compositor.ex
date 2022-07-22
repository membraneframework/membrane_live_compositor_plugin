defmodule Membrane.VideoCompositor.Merger do
  @moduledoc """
  Compositor, that takes one raw video, duplicate frames and merge them.
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.Buffer

  def_input_pad(:input,
                demand_unit: :buffers,
                demand_mode: :auto,
                caps: {RawVideo, pixel_format: :I420})

  def_output_pad(:output,
                demand_unit: :buffers,
                demand_mode: :auto,
                caps: {RawVideo, pixel_format: :I420})

  @impl true
  def handle_init(_options) do
    state = %{}
    {:ok, state}
  end

  @impl true
  def handle_process(:input, buffer, _contex, state) do
    {:ok, merged_frame_binary} = Membrane.VideoCompositor.CompositorImplementation.merge_frames(buffer.payload, buffer.payload)
    merged_image_buffer = %Buffer{buffer | payload: merged_frame_binary}
    {{:ok, buffer: {:output, merged_image_buffer}}, state}
  end

  @impl true
  def handle_caps(:input, %RawVideo{width: 1280, height: 720} = caps, _context, state) do
    caps = %{caps | height: caps.height * 2}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_end_of_stream(:input, _context, state) do
    {{:ok, end_of_stream: :output, notify: {:end_of_stream, :input}}, state}
  end
end
