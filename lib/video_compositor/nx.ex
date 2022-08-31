defmodule Membrane.VideoCompositor.Nx do
  @moduledoc """
  This module implements video composition in Nx.
  It receives two frames in binary format,
  concatenate separate yuv components,
  and merges them.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  @impl true
  def init(caps) do
    {:ok, caps}
  end

  @impl true
  def merge_frames(frames, internal_state) do
    first_frame_nxtensor = Nx.from_binary(frames.first, {:u, 8})
    second_frame_nxtensor = Nx.from_binary(frames.second, {:u, 8})

    first_v_value_index = floor(internal_state.width * internal_state.height * 5 / 4)
    frame_length = floor(internal_state.width * internal_state.height * 3 / 2)

    y =
      Nx.concatenate([
        first_frame_nxtensor[0..(internal_state.width * internal_state.height - 1)],
        second_frame_nxtensor[0..(internal_state.width * internal_state.height - 1)]
      ])

    u =
      Nx.concatenate([
        first_frame_nxtensor[
          (internal_state.width * internal_state.height)..(first_v_value_index - 1)
        ],
        second_frame_nxtensor[
          (internal_state.width * internal_state.height)..(first_v_value_index - 1)
        ]
      ])

    v =
      Nx.concatenate([
        first_frame_nxtensor[first_v_value_index..(frame_length - 1)],
        second_frame_nxtensor[first_v_value_index..(frame_length - 1)]
      ])

    merged_frames_nxtensor = Nx.concatenate([y, u, v])
    merged_frames_binary = Nx.to_binary(merged_frames_nxtensor)

    {{:ok, merged_frames_binary}, internal_state}
  end
end
