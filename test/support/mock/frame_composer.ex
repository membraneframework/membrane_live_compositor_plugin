defmodule Membrane.VideoCompositor.Test.Support.Mock.FrameComposer do
  @moduledoc """
  Mock frame composer for multiple input videos. It supports string buffers and concatenates them as an output.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  @impl true
  def init(_output_caps) do
    state = %{
      merged_ids: [],
      inputs: %{}
    }

    {:ok, state}
  end

  @impl true
  def merge_frames(%{merged_ids: merged_ids} = internal_state, frames) do
    {ids, frames} = Enum.unzip(frames)
    internal_state = %{internal_state | merged_ids: [ids | merged_ids]}

    concatenated =
      frames
      |> Enum.join("")

    {{:ok, concatenated}, internal_state}
  end

  @impl true
  def add_video(
        %{inputs: inputs} = internal_state,
        id,
        input_caps,
        _position,
        _z \\ 0.0
      ) do
    internal_state = %{internal_state | inputs: Map.put(inputs, id, input_caps)}
    {:ok, internal_state}
  end

  @impl true
  def remove_video(%{inputs: inputs} = internal_state, id) do
    internal_state = %{internal_state | inputs: Map.delete(inputs, id)}
    {:ok, internal_state}
  end

  @impl true
  def set_position(
        internal_state,
        _id,
        _position,
        _z \\ 0.0
      ) do
    {:ok, internal_state}
  end
end
