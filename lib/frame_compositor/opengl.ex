defmodule Membrane.VideoCompositor.OpenGL do
  @moduledoc """
  This module implements video composition in OpenGL.
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  @impl true
  def init(_caps) do
    {:ok, %{}}
  end

  @impl true
  def merge_frames(frames, internal_state) do
    merged_frames_binary = frames.first <> frames.second
    {{:ok, merged_frames_binary}, internal_state}
  end
end
