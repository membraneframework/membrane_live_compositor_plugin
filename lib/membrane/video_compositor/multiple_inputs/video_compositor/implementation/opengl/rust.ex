defmodule Membrane.VideoCompositor.MultipleInputs.OpenGL.Rust do
  @moduledoc """
  This module implements video composition in OpenGL with a Rust backend
  """
  @behaviour Membrane.VideoCompositor.MultipleInputs.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust

  @impl true
  def init(output_caps) do
    {:ok, output_caps} = Rust.RawVideo.from_membrane_raw_video(output_caps)
    Rust.init(output_caps)
  end

  @impl true
  def add_video(id, input_caps, position, internal_state) do
    {:ok, input_caps} = Rust.RawVideo.from_membrane_raw_video(input_caps)
    {:ok, position} = Rust.Position.from_tuple(position)
    {Rust.add_video(internal_state, id, input_caps, position), internal_state}
  end

  @impl true
  def remove_video(id, internal_state) do
    {Rust.remove_video(internal_state, id), internal_state}
  end

  @impl true
  def merge_frames(frames, internal_state) do
    {Rust.join_frames(internal_state, frames), internal_state}
  end

  @impl true
  def set_position(id, position, internal_state) do
    {:ok, position} = Rust.Position.from_tuple(position)
    {Rust.set_position(internal_state, id, position), internal_state}
  end
end
