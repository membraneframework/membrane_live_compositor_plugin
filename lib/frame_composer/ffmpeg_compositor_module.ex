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
    videos = [first_video, second_video]

    FFmpeg.init(videos)
  end

  @impl Membrane.VideoCompositor.FrameCompositor
  def merge_frames(frames, state_of_init_module) do
    frames = [frames.first, frames.second]

    {:ok, merged_frames_binary} = FFmpeg.apply_filter(frames, state_of_init_module)
    {:ok, merged_frames_binary, state_of_init_module}
  end
end
