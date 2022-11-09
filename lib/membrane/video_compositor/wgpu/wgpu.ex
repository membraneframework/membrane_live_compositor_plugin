defmodule Membrane.VideoCompositor.Wgpu do
  @moduledoc """
  This module implements video composition in wgpu
  """

  alias Membrane.VideoCompositor.Common
  alias Membrane.VideoCompositor.Wgpu.Native

  @type id_t() :: non_neg_integer()
  @type internal_state_t() :: any()
  @type error_t() :: any()
  @type frame_t() :: binary()
  @type pts_t() :: Membrane.Time.t()
  @type frame_with_pts_t :: {binary(), pts_t()}

  @spec init(Membrane.RawVideo.t()) :: {:error, any} | {:ok, any}
  def init(output_caps) do
    {:ok, output_caps} = Common.RawVideo.from_membrane_raw_video(output_caps)
    Native.init(output_caps)
  end

  @doc """
  Uploads a frame to the compositor.

  If all videos have provided input frames with a current enough pts, this will also render and return a composed frame.
  """
  @spec upload_frame(internal_state_t(), id_t(), frame_with_pts_t()) ::
  {:ok | {:ok, frame_with_pts_t()}, internal_state_t()}
  def upload_frame(state, id, {frame, pts}) do
    case Native.upload_frame(state, id, frame, pts) do
      :ok ->
        {:ok, state}

      {:ok, frame} ->
        {{:ok, frame}, state}

      {:error, reason} ->
        raise "Error while uploading/composing frame, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Forcibly renders the composed frame, even if we are still waiting for some frames to arrive
  """
  @spec force_render(internal_state :: internal_state_t) ::
              {{:ok, merged_frames :: frame_with_pts_t()}, internal_state_t} | {:error, error_t()}

  def force_render(state) do
    case Native.force_render(state) do
      {:ok, frame} -> {{:ok, frame}, state}
      {:error, reason} -> raise "Error while force rendering, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Registers a new input video with the given numerical `id`.

  Provided `id` should be unique within all previous ones, otherwise the compositor may or may not replace
  the old video with this id with a new one.
  `x` and `y` are pixel coordinates specifying where the top-left corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a higher `z` coordinate will cover videos with lower `z` coordinates.
  """
  @spec add_video(
              internal_state :: internal_state_t,
              id :: id_t(),
              input_caps :: Membrane.RawVideo.t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              z :: float(),
              scale :: float()
            ) :: {:ok, internal_state_t} | {:error, error_t()}
  def add_video(state, id, input_caps, {x, y}, z \\ 0.0, scale \\ 1.0) do
    {:ok, input_caps} = Common.RawVideo.from_membrane_raw_video(input_caps)
    properties = Common.VideoProperties.from_tuple({x, y, z, scale})

    case Native.add_video(state, id, input_caps, properties) do
      :ok -> {:ok, state}
      {:error, reason} -> raise "Error while adding a video, reason: #{inspect(reason)}"
    end
  end

  @doc """
  `x` and `y` are pixel coordinates specifying where the top-left corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a higher `z` coordinate will cover videos with lower `z` coordinates.
  """
  @spec set_properties(
              internal_state :: internal_state_t,
              id :: id_t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              z :: float(),
              scale :: float()
            ) :: {:ok, internal_state_t} | {:error, error_t()}
  def set_properties(state, id, {x, y}, z \\ 0.0, scale \\ 1.0) do
    properties = Common.VideoProperties.from_tuple({x, y, z, scale})

    case Native.set_properties(state, id, properties) do
      :ok -> {:ok, state}
      {:error, reason} -> raise "Error while setting video properties, reason: #{inspect(reason)}"
    end
  end

  @doc """
  If the video doesn't exist this will return an error.
  """
  @spec remove_video(
              internal_state :: internal_state_t,
              id :: id_t()
            ) :: {:ok, internal_state_t} | {:error, error_t()}
  def remove_video(state, id) do
    case Native.remove_video(state, id) do
      :ok -> {:ok, state}
      {:error, reason} -> raise "Error while removing a video, reason: #{inspect(reason)}"
    end
  end

  @doc """
  Send an end of stream to a video with the given `id`.

  This causes the video to be deleted after it's enqueued frames are used up.
  """
  @spec send_end_of_stream(internal_state_t(), id_t()) ::
              {:ok, internal_state_t()} | {:error, error_t()}
  def send_end_of_stream(state, id) do
    case Native.send_end_of_stream(state, id) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        raise "Error while sending an end of stream message to a video, reason: #{inspect(reason)}"
    end
  end
end
