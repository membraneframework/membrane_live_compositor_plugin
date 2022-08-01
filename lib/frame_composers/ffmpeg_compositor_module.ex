defmodule Membrane.VideoCompositor.FFMPEG do
  @moduledoc """
  This module implements video composition in ffmpeg.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.FFmpeg.Native, as: FFmpeg

  @impl Membrane.VideoCompositor.FrameCompositor
  def init(caps) do
    first_video = caps
    second_video = caps

    FFmpeg.init(
      first_video,
      second_video
    )
  end

  @impl Membrane.VideoCompositor.FrameCompositor
  def merge_frames(frames, state_of_init_module) do
    FFmpeg.apply_filter(frames.first, frames.second, state_of_init_module)
  end
end
