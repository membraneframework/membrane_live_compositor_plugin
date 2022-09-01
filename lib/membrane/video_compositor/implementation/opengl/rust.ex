defmodule Membrane.VideoCompositor.Implementations.OpenGL.Rust do
  @moduledoc """
  This module implements video composition in OpenGL with a Rust backend
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust

  @impl true
  def init(%Membrane.RawVideo{width: width, height: height, pixel_format: pixel_format}) do
    input_caps = %Rust.RawVideo{width: width, height: height, pixel_format: pixel_format}
    output_caps = %Rust.RawVideo{input_caps | height: 2 * height}

    {:ok, internal_state} = Rust.init(output_caps)

    Rust.add_video(internal_state, 0, input_caps, %Rust.Position{x: 0, y: 0})
    Rust.add_video(internal_state, 1, input_caps, %Rust.Position{x: 0, y: input_caps.height})

    {:ok, internal_state}
  end

  @impl true
  def merge_frames(%{first: first, second: second}, internal_state) do
    {Rust.join_frames(internal_state, [first, second]), internal_state}
  end
end
