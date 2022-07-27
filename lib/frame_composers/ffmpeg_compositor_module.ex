defmodule Membrane.VideoCompositor.FFMPEG do
  @moduledoc """
  This module implements video composition in ffmpeg using Membrane.VideoCompositor.FrameCompositor behaviour.
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
