defmodule Membrane.VideoCompositor.FFMPEG do
  @moduledoc """
  This module implements video composition in ffmpeg.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.FFmpeg.Native, as: FFmpeg
  alias Membrane.VideoCompositor.FFmpeg.Native.RawVideo, as: NativeRawVideo

  @impl true
  def init(caps) do
    {:ok, video} = NativeRawVideo.from_membrane_raw_video(caps)
    videos = [video, video]

    FFmpeg.init(videos)
  end

  @impl true
  def merge_frames(frames, state_of_init_module) do
    frames = [frames.first, frames.second]

    {:ok, merged_frames_binary} = FFmpeg.apply_filter(frames, state_of_init_module)
    {{:ok, merged_frames_binary}, state_of_init_module}
  end
end
