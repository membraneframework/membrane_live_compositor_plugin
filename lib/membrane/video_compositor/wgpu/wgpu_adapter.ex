defmodule Membrane.VideoCompositor.WgpuAdapter do
  @moduledoc false

  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.{Pad, RawVideo}
  alias Membrane.VideoCompositor.{RustStructs, Scene}
  alias Membrane.VideoCompositor.Wgpu.Native

  @type wgpu_state() :: any()
  @type error() :: any()
  @type frame() :: binary()
  @type pts() :: Membrane.Time.t()
  @type frame_with_pts :: {binary(), pts()}
  @type video_id() :: non_neg_integer()

  @spec init(RawVideo.t()) :: {:error, wgpu_state()} | {:ok, wgpu_state()}
  def init(output_stream_format) do
    output_stream_format = RustStructs.RawVideo.from_membrane_raw_video(output_stream_format)

    Native.init(output_stream_format)
  end

  @doc """
  Uploads a frame to the compositor.

  Uploads frames to core part of VC one by one. If all videos have frames with proper pts values, this will return composed frame.
  """
  @spec process_frame(wgpu_state(), video_id(), frame_with_pts()) ::
          :ok | {:ok, frame_with_pts()}
  def process_frame(state, video_id, {frame, pts}) do
    case Native.process_frame(state, video_id, frame, pts) do
      :ok ->
        :ok

      {:ok, frame} ->
        {:ok, frame}

      {:error, reason} ->
        raise "Error while uploading/composing frame, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Sets VC videos properties.
  """
  @spec set_videos(wgpu_state(), CompositorCoreFormat.t(), Scene.t(), %{Pad.ref() => video_id()}) ::
          :ok
  def set_videos(state, %CompositorCoreFormat{pad_formats: pad_formats}, scene, pads_to_ids) do
    rust_stream_format =
      Map.new(pad_formats, fn {pad, raw_video = %RawVideo{}} ->
        {Map.fetch!(pads_to_ids, pad), RustStructs.RawVideo.from_membrane_raw_video(raw_video)}
      end)

    rust_scene = RustStructs.Scene.from_vc_scene(scene, pads_to_ids)

    case Native.set_videos(state, rust_stream_format, rust_scene) do
      :ok ->
        :ok

      {:error, reason} ->
        raise "Error while setting scene, reason: #{inspect(reason)}"
    end
  end
end
