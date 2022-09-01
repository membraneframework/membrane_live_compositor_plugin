defmodule Membrane.VideoCompositor.OpenGL.Rust do
  @moduledoc """
  This module implements video composition in OpenGL with a Rust backend
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.OpenGL.Native.Rust

  @impl true
  def init(%Membrane.RawVideo{width: width, height: height, pixel_format: pixel_format}) do
    input_caps = %Rust.RawVideo{width: width, height: height, pixel_format: pixel_format}
    output_caps = %Rust.RawVideo{input_caps | height: 2 * height}

    Rust.init(input_caps, input_caps, output_caps)
  end

  @impl true
  def merge_frames(%{first: first, second: second}, internal_state) do
    {Rust.join_frames(internal_state, first, second), internal_state}
  end
end
