defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  Implement merge_frames(first_frame_binary, second_frame_binary, implementation) function,
  that place first frame above the other and returns binary format of merged frames.
  """
  import Nx.Defn

  def merge_frames(first_frame_binary, second_frame_binary, implementation) do
    case implementation do
      :ffmpeg ->
        {:ok, 'not implemented yet'}

      :opengl ->
        {:ok, 'not implemented yet'}

      :nx ->
        first_frame_nxtensor = Nx.from_binary(first_frame_binary, {:u, 8})
        second_frame_nxtensor = Nx.from_binary(second_frame_binary, {:u, 8})
        merged_frames_nxtensor = merge_frames_nx(first_frame_nxtensor, second_frame_nxtensor)

        merged_frames_binary = Nx.to_binary(merged_frames_nxtensor)
        {:ok, merged_frames_binary}
    end
  end

  defnp merge_frames_nx(first_frame_nxtensor, second_frame_nxtensor) do
    {frame_width, frame_height} = {1280, 720}  # TO DO change this to be passed in options

    first_v_value_index = floor_number(frame_width * frame_height * 5 / 4)
    frame_length = floor_number(frame_width * frame_height * 3 / 2)

    y =
      Nx.concatenate([
        first_frame_nxtensor[0..(frame_width * frame_height - 1)],
        second_frame_nxtensor[0..(frame_width * frame_height - 1)]
      ])

    u =
      Nx.concatenate([
        first_frame_nxtensor[(frame_width * frame_height)..(first_v_value_index - 1)],
        second_frame_nxtensor[(frame_width * frame_height)..(first_v_value_index - 1)]
      ])

    v =
      Nx.concatenate([
        first_frame_nxtensor[first_v_value_index..(frame_length - 1)],
        second_frame_nxtensor[first_v_value_index..(frame_length - 1)]
      ])

    Nx.concatenate([y, u, v])
  end

  defnp floor_number(value) do
    transform(value, &floor/1)
  end
end
