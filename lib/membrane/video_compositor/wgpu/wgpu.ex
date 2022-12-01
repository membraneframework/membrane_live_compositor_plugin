defmodule Membrane.VideoCompositor.Wgpu do
  @moduledoc """
  This module implements video composition in wgpu
  """

  alias Membrane.VideoCompositor.RustStructs
  alias Membrane.VideoCompositor.Wgpu.Native

  @type id_t() :: non_neg_integer()
  @type wgpu_state_t() :: any()
  @type error_t() :: any()
  @type frame_t() :: binary()
  @type pts_t() :: Membrane.Time.t()
  @type frame_with_pts_t :: {binary(), pts_t()}

  @spec init(Membrane.RawVideo.t()) :: {:error, wgpu_state_t()} | {:ok, wgpu_state_t()}
  def init(output_caps) do
    {:ok, output_caps} = RustStructs.RawVideo.from_membrane_raw_video(output_caps)
    Native.init(output_caps)
  end

  @doc """
  Uploads a frame to the compositor.

  If all videos have provided input frames with a current enough pts, this will also render and return a composed frame.
  """
  @spec upload_frame(wgpu_state_t(), id_t(), frame_with_pts_t()) ::
          :ok | {:ok, frame_with_pts_t()}
  def upload_frame(state, id, {frame, pts}) do
    case Native.upload_frame(state, id, frame, pts) do
      :ok ->
        :ok

      {:ok, frame} ->
        {:ok, frame}

      {:error, reason} ->
        raise "Error while uploading/composing frame, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Forcibly renders the composed frame, even if we are still waiting for some frames to arrive
  """
  @spec force_render(state :: wgpu_state_t()) ::
          {:ok, merged_frames :: frame_with_pts_t()} | {:error, error_t()}

  def force_render(state) do
    case Native.force_render(state) do
      {:ok, frame} -> {:ok, frame}
      {:error, reason} -> raise "Error while force rendering, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Set input video with the given numerical `id`.
  Used for adding new input videos as well as updating properties of existing ones.

  Provided `id` should be unique within all previous ones, otherwise the compositor may or may not replace
  the old video with this id with a new one.
  `x` and `y` are pixel coordinates specifying where the top-left corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a higher `z` coordinate will cover videos with lower `z` coordinates.
  """
  @spec put_video(
          state :: wgpu_state_t(),
          id :: id_t(),
          caps :: Membrane.RawVideo.t(),
          layout :: RustStructs.VideoLayout.t()
        ) :: :ok | {:error, error_t()}
  def put_video(state, id, caps, layout) do
    {:ok, caps} = RustStructs.RawVideo.from_membrane_raw_video(caps)

    case Native.put_video(state, id, caps, layout) do
      :ok -> :ok
      {:error, reason} -> raise "Error while adding a video, reason: #{inspect(reason)}"
    end
  end

  @doc """
  If the video doesn't exist this will return an error.
  """
  @spec remove_video(
          state :: wgpu_state_t(),
          id :: id_t()
        ) :: :ok | {:error, error_t()}
  def remove_video(state, id) do
    case Native.remove_video(state, id) do
      :ok -> :ok
      {:error, reason} -> raise "Error while removing a video, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Send an end of stream to a video with the given `id`.

  This causes the video to be deleted after it's enqueued frames are used up.
  """
  @spec send_end_of_stream(wgpu_state_t(), id_t()) ::
          :ok | {:error, error_t()}
  def send_end_of_stream(state, id) do
    case Native.send_end_of_stream(state, id) do
      :ok ->
        :ok

      {:error, reason} ->
        raise "Error while sending an end of stream message to a video, reason: #{inspect(reason)}"
    end
  end
end
