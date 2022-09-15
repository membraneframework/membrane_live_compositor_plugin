defmodule Membrane.VideoCompositor.Wgpu do
  @moduledoc """
  This module implements video composition in wgpu
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.RawVideo
  alias Membrane.VideoCompositor.Implementations.Wgpu.Native

  @impl true
  def init(%Membrane.RawVideo{width: width, height: height, pixel_format: pixel_format}) do
    input_caps = %RawVideo{width: width, height: height, pixel_format: pixel_format}
    output_caps = %RawVideo{input_caps | height: 2 * height}

    Native.init(input_caps, input_caps, output_caps)
  end

  @impl true
  def merge_frames(%{first: first, second: second}, state) do
    {Native.join_frames(state, first, second), state}
  end
end
