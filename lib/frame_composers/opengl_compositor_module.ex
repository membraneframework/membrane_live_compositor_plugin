defmodule Membrane.VideoCompositor.OpenGL do
  @moduledoc """
  This module implements video composition in OpenGL.
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  @impl Membrane.VideoCompositor.FrameCompositor
  def init(_caps) do
    # placeholder
    {:ok, %{}}
  end

  @impl Membrane.VideoCompositor.FrameCompositor
  def merge_frames(frames_binaries, _caps) do
    # placeholder
    merged_frames_binary = frames_binaries.first_frame_binary
    {:ok, merged_frames_binary}
  end
end
