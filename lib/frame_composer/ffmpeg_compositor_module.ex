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

    {:ok, state} = FFmpeg.init(videos)
    {:ok, %{state: state, iter: 0}}
  end

  @impl Membrane.VideoCompositor.FrameCompositor
  def merge_frames(frames, state_of_init_module) do
    %{state: state_of_init_module, iter: iter} = state_of_init_module
    videos = [frames.first, frames.second]

    {:ok, merged_frames_binary} = FFmpeg.apply_filter(videos, state_of_init_module)
    {:ok, merged_frames_binary, %{state: state_of_init_module, iter: iter + 1}}
  end
end
