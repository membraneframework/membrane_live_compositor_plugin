defmodule Membrane.VideoCompositor.Nx do
  @moduledoc """
  This module implements video composition in Nx.
  It implements Membrane.VideoCompositor.FrameCompositor
  behaviour. In merge_frames function it receives two frames
  in binary format, concatenate separate yuv components,
  and merges them together.
  """
  @behaviour Membrane.VideoCompositor.FrameCompositor

  @impl Membrane.VideoCompositor.FrameCompositor
  def init(caps) do
    {:ok, caps}
  end

  @impl Membrane.VideoCompositor.FrameCompositor
  def merge_frames(frames, state_of_init_module) do
    first_frame_nxtensor = Nx.from_binary(frames.first, {:u, 8})
    second_frame_nxtensor = Nx.from_binary(frames.second, {:u, 8})

    first_v_value_index = floor(state_of_init_module.width * state_of_init_module.height * 5 / 4)
    frame_length = floor(state_of_init_module.width * state_of_init_module.height * 3 / 2)

    y =
      Nx.concatenate([
        first_frame_nxtensor[0..(state_of_init_module.width * state_of_init_module.height - 1)],
        second_frame_nxtensor[0..(state_of_init_module.width * state_of_init_module.height - 1)]
      ])

    u =
      Nx.concatenate([
        first_frame_nxtensor[
          (state_of_init_module.width * state_of_init_module.height)..(first_v_value_index - 1)
        ],
        second_frame_nxtensor[
          (state_of_init_module.width * state_of_init_module.height)..(first_v_value_index - 1)
        ]
      ])

    v =
      Nx.concatenate([
        first_frame_nxtensor[first_v_value_index..(frame_length - 1)],
        second_frame_nxtensor[first_v_value_index..(frame_length - 1)]
      ])

    merged_frames_nxtensor = Nx.concatenate([y, u, v])
    merged_frames_binary = Nx.to_binary(merged_frames_nxtensor)

    {:ok, merged_frames_binary}
  end
end
