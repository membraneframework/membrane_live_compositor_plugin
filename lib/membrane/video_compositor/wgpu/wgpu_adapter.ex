defmodule Membrane.VideoCompositor.WgpuAdapter do
  @moduledoc false

  alias Membrane.VideoCompositor.RustStructs
  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.Wgpu.Native

  @type id() :: non_neg_integer()
  @type wgpu_state() :: any()
  @type error() :: any()
  @type frame() :: binary()
  @type pts() :: Membrane.Time.t()
  @type frame_with_pts :: {binary(), pts()}

  @spec init(Membrane.RawVideo.t()) :: {:error, wgpu_state()} | {:ok, wgpu_state()}
  def init(output_stream_format) do
    {:ok, output_stream_format} =
      RustStructs.RawVideo.from_membrane_raw_video(output_stream_format)

    Native.init(output_stream_format)
  end

  @doc """
  Uploads a frame to the compositor.

  If all videos have provided input frames with a current enough pts, this will also render and return a composed frame.
  """
  @spec process_frame(wgpu_state(), id(), frame_with_pts()) ::
          :ok | {:ok, frame_with_pts()}
  def process_frame(state, id, {frame, pts}) do
    case Native.process_frame(state, id, frame, pts) do
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
  @spec force_render(state :: wgpu_state()) ::
          {:ok, merged_frames :: frame_with_pts()} | {:error, error()}

  def force_render(state) do
    case Native.force_render(state) do
      {:ok, frame} -> {:ok, frame}
      {:error, reason} -> raise "Error while force rendering, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Add an input video with the given numerical `id`.

  Provided `id` should be unique within all previous ones. If a video with a given id already exists in the compositor, this will raise.
  """
  @spec add_video(
          state :: wgpu_state(),
          id :: id(),
          stream_format :: Membrane.RawVideo.t(),
          placement :: RustStructs.BaseVideoPlacement.t(),
          transformations :: VideoTransformations.t()
        ) :: :ok | {:error, error()}
  def add_video(state, id, stream_format, placement, transformations) do
    {:ok, rust_stream_format} = RustStructs.RawVideo.from_membrane_raw_video(stream_format)

    case Native.add_video(state, id, rust_stream_format, placement, transformations) do
      :ok -> :ok
      {:error, reason} -> raise "Error while adding a video, reason: #{inspect(reason)}"
    end
  end

  @doc """
  If the video doesn't exist this will return an error.
  """
  @spec remove_video(
          state :: wgpu_state(),
          id :: id()
        ) :: :ok | {:error, error()}
  def remove_video(state, id) do
    case Native.remove_video(state, id) do
      :ok -> :ok
      {:error, reason} -> raise "Error while removing a video, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Update input stream_format for the given video.
  """
  @spec update_stream_format(
          state :: wgpu_state(),
          id :: id(),
          stream_format :: Membrane.RawVideo.t()
        ) ::
          :ok
  def update_stream_format(state, id, stream_format) do
    {:ok, rust_stream_format} = RustStructs.RawVideo.from_membrane_raw_video(stream_format)

    case Native.update_stream_format(state, id, rust_stream_format) do
      :ok ->
        :ok

      {:error, reason} ->
        raise "Error while updating video stream_format, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Update placement for the given video.
  """
  @spec update_placement(
          state :: wgpu_state(),
          id :: id(),
          placement :: RustStructs.BaseVideoPlacement.t()
        ) :: :ok | {:error, :bad_video_index}
  def update_placement(state, id, placement) do
    case Native.update_placement(state, id, placement) do
      :ok -> :ok
      {:error, {:bad_video_index, _index}} -> {:error, :bad_video_index}
      {:error, reason} -> raise "Error while updating video placement, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Update transformations for the given video.
  """
  @spec update_transformations(
          state :: wgpu_state(),
          id :: id(),
          transformations :: Membrane.VideoCompositor.VideoTransformations.t()
        ) :: :ok | {:error, :bad_video_index}
  def update_transformations(state, id, transformations) do
    case Native.update_transformations(state, id, transformations) do
      :ok ->
        :ok

      {:error, {:bad_video_index, _index}} ->
        {:error, :bad_video_index}

      {:error, reason} ->
        raise "Error while updating video transformations, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Send an end of stream to a video with the given `id`.

  This causes the video to be deleted after it's enqueued frames are used up.
  """
  @spec send_end_of_stream(wgpu_state(), id()) ::
          {:ok, [frame_with_pts()]}
  def send_end_of_stream(state, id) do
    case Native.send_end_of_stream(state, id) do
      {:ok, frames} ->
        {:ok, frames}

      {:error, reason} ->
        raise "Error while sending an end of stream message to a video, reason: #{inspect(reason)}"
    end
  end
end
