defmodule Membrane.VideoCompositor.FFMPEG.Research do
  @moduledoc """
  This module implements video composition in ffmpeg.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.FFmpeg.Native, as: FFmpeg
  alias Membrane.RawVideo

  @impl Membrane.VideoCompositor.FrameCompositor
  def init(caps) do
    {num, den} = caps.framerate
    video = %RawVideo{caps | framerate: div(num, den)}

    videos = [video, video]

    {:ok, internal_state} = FFmpeg.init(videos)
    {:ok, %{state: internal_state, iter: 1, raw_video: video}}
  end

  @impl Membrane.VideoCompositor.FrameCompositor
  def merge_frames(frames, state_of_init_module) do
    %{state: internal_state, iter: iter} = state_of_init_module

    repeated_frames = Stream.repeatedly(fn -> frames.second end) |> Enum.take(div(iter, 80))
    frames = [frames.first, frames.second] ++ repeated_frames

    internal_state =
      if rem(iter, 80) == 0 do
        raw_videos = for _ <- 1..(div(iter, 80) + 2), do: state_of_init_module.raw_video

        {:ok, new_internal_state} = FFmpeg.init(raw_videos)
        {:ok, new_internal_state} = FFmpeg.duplicate_metadata(new_internal_state, internal_state)
        new_internal_state
      else
        internal_state
      end

    {:ok, merged_frames_binary} = FFmpeg.apply_filter(frames, internal_state)
    {:ok, merged_frames_binary, %{state_of_init_module | state: internal_state, iter: iter + 1}}
  end
end
