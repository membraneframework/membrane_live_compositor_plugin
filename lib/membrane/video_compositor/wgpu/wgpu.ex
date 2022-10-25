defmodule Membrane.VideoCompositor.Wgpu do
  @moduledoc """
  This module implements video composition in wgpu
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Common.{Position, RawVideo}
  alias Membrane.VideoCompositor.Wgpu.Native

  @impl true
  def init(output_caps) do
    {:ok, output_caps} = RawVideo.from_membrane_raw_video(output_caps)
    Native.init(output_caps)
  end

  @impl true
  def merge_frames(internal_state, frames) do
    {Native.render_frame(internal_state, frames), internal_state}
  end

  @impl true
  def add_video(internal_state, id, input_caps, {x, y}, z \\ 0.0) do
    {:ok, input_caps} = RawVideo.from_membrane_raw_video(input_caps)
    position = Position.from_tuple({x, y, z})
    :ok = Native.add_video(internal_state, id, input_caps, position)
    {:ok, internal_state}
  end

  @impl true
  def set_position(internal_state, id, {x, y}, z \\ 0.0) do
    position = Position.from_tuple({x, y, z})
    {Native.set_position(internal_state, id, position), internal_state}
  end

  @impl true
  def remove_video(internal_state, id) do
    :ok = Native.remove_video(internal_state, id)
    {:ok, internal_state}
  end
end
