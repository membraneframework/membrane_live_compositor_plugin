defmodule Membrane.VideoCompositor.FFmpeg.Research do
  @moduledoc """
  This module is used for ffmpeg research purposes.
  It dynamically composes several input videos, adding one video every 80 frames.

  Composition starts with two videos, one above of the other.
  Every 80 frames one new video (copy of the second input one, to be precise) is added to the composition.
  Every next video is rendered on the previous ones,
  being positioned slightly higher (following the harmonic series).
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.FFmpeg.Native, as: FFmpeg
  alias Membrane.VideoCompositor.FFmpeg.Native.RawVideo, as: NativeRawVideo

  @impl true
  def init(caps) do
    {:ok, video} = NativeRawVideo.from_membrane_raw_video(caps)

    videos = [video, video]

    {:ok, internal_state} = FFmpeg.init(videos)
    {:ok, %{state: internal_state, iter: 1, raw_video: video}}
  end

  @impl true
  def merge_frames(frames, %{internal_state: internal_state, iter: iter} = state) do
    repeated_frames = Stream.repeatedly(fn -> frames.second end) |> Enum.take(div(iter, 80))
    frames = [frames.first, frames.second] ++ repeated_frames

    internal_state =
      if rem(iter, 80) == 0 do
        raw_videos = for _n <- 1..(div(iter, 80) + 2), do: state.raw_video

        {:ok, new_internal_state} = FFmpeg.init(raw_videos)
        {:ok, new_internal_state} = FFmpeg.duplicate_metadata(new_internal_state, internal_state)
        new_internal_state
      else
        internal_state
      end

    {:ok, merged_frames_binary} = FFmpeg.apply_filter(frames, internal_state)
    {{:ok, merged_frames_binary}, %{state | internal_state: internal_state, iter: iter + 1}}
  end
end
