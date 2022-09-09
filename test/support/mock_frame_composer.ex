defmodule Membrane.VideoCompositor.Test.Mock.FrameComposer.MultipleInput do
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
  def merge_frames(frames, %{merged_ids: merged_ids} = internal_state) do
    {ids, frames} = Enum.unzip(frames)
    internal_state = %{internal_state | merged_ids: [ids | merged_ids]}

    concatenated =
      frames
      |> Enum.join("")

    {{:ok, concatenated}, internal_state}
  end

  @impl true
  def add_video(
        id,
        input_caps,
        _position,
        %{inputs: inputs} = internal_state
      ) do
    internal_state = %{internal_state | inputs: Map.put(inputs, id, input_caps)}
    {:ok, internal_state}
  end

  @impl true
  def remove_video(id, %{inputs: inputs} = internal_state) do
    internal_state = %{internal_state | inputs: Map.delete(inputs, id)}
    {:ok, internal_state}
  end

  @impl true
  def set_position(
        _id,
        _position,
        internal_state
      ) do
    {:ok, internal_state}
  end
end
