defmodule Membrane.VideoCompositor.MultipleInputs.OpenGL.Rust do
  @moduledoc """
  This module implements video composition in OpenGL with a Rust backend
  """
  @behaviour Membrane.VideoCompositor.MultipleInputs.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Implementation.OpenGL.Native.Rust

  @impl true
  def init(output_caps) do
    Rust.init(output_caps)
  end

  @impl true
  def add_video(id, input_caps, position, internal_state) do
    {Rust.add_video(internal_state, id, input_caps, position), internal_state}
  end

  @impl true
  def remove_video(id, internal_state) do
    {Rust.remove_video(internal_state, id), internal_state}
  end

  @impl true
  def merge_frames(frames, internal_state) do
    {Rust.join_frames(internal_state, Map.to_list(frames)), internal_state}
  end

  @impl true
  def set_position(id, position, internal_state) do
    {Rust.set_position(internal_state, id, position), internal_state}
  end
end
