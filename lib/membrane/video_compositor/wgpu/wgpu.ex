defmodule Membrane.VideoCompositor.Wgpu do
  @moduledoc """
  This module implements video composition in wgpu
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Common.{RawVideo, VideoProperties}
  alias Membrane.VideoCompositor.Wgpu.Native

  @impl true
  def init(output_caps) do
    {:ok, output_caps} = RawVideo.from_membrane_raw_video(output_caps)
    Native.init(output_caps)
  end

  @impl true
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

  @impl true
  def force_render(state) do
    case Native.force_render(state) do
      {:ok, frame} -> {{:ok, frame}, state}
      {:error, reason} -> raise "Error while force rendering, reason: #{inspect(reason)}"
    end
  end

  @impl true
  def add_video(state, id, input_caps, {x, y}, z \\ 0.0, scale \\ 1.0) do
    {:ok, input_caps} = RawVideo.from_membrane_raw_video(input_caps)
    position = VideoProperties.from_tuple({x, y, z, scale})

    case Native.add_video(state, id, input_caps, position) do
      :ok -> {:ok, state}
      {:error, reason} -> raise "Error while adding a video, reason: #{inspect(reason)}"
    end
  end

  @impl true
  def set_position(state, id, {x, y}, z \\ 0.0, scale \\ 1.0) do
    position = VideoProperties.from_tuple({x, y, z, scale})

    case Native.set_position(state, id, position) do
      :ok -> {:ok, state}
      {:error, reason} -> raise "Error while setting a video position, reason: #{inspect(reason)}"
    end
  end

  @impl true
  def remove_video(state, id) do
    case Native.remove_video(state, id) do
      :ok -> {:ok, state}
      {:error, reason} -> raise "Error while removing a video, reason: #{inspect(reason)}"
    end
  end

  @impl true
  def send_end_of_stream(state, id) do
    case Native.send_end_of_stream(state, id) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        raise "Error while sending an end of stream message to a video, reason: #{inspect(reason)}"
    end
  end
end
