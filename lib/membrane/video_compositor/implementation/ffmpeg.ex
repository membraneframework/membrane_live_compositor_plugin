defmodule Membrane.VideoCompositor.Implementation.FFmpeg do
  @moduledoc """
  This module implements video composition in ffmpeg.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Implementation.FFmpeg.Native, as: FFmpeg
  alias Membrane.VideoCompositor.Implementation.FFmpeg.Native.RawVideo, as: NativeRawVideo

  @impl true
  def init(caps) do
    {:ok, video} = NativeRawVideo.from_membrane_raw_video(caps)
    videos = [video, video]

    FFmpeg.init(videos)
  end

  @impl true
  def merge_frames(frames, state) do
    frames = [frames.first, frames.second]

    {:ok, merged_frames_binary} = FFmpeg.apply_filter(frames, state)
    {{:ok, merged_frames_binary}, state}
  end
end
