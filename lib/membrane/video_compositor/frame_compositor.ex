defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations, supporting multiple input frames.
  """
  alias Membrane.RawVideo

  @type id_t() :: non_neg_integer()
  @type internal_state_t() :: any()
  @type error_t() :: any()

  @callback init(output_caps :: RawVideo.t()) :: {:ok, internal_state_t} | {:error, error_t()}

  @doc """
  Frames are provided as tuples `{id, frame}` and given in the proper order of rendering (typically in ascending order of ids).
  Providing frames with wrong ids may cause undefined behaviour.
  """
  @callback merge_frames(
              internal_state :: internal_state_t,
              frames :: [{id_t, binary()}]
            ) :: {{:ok, merged_frames :: binary()}, internal_state_t} | {:error, error_t()}

  @doc """
  Registers a new input video with the given numerical `id`.
  Provided `id` should be unique within all previous ones, otherwise function may cause undefined behaviour.
  `x` and `y` are pixel coordinates specifying where the top-right corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a lower `z` coordinate will cover videos with higher `z` coordinates.
  """
  @callback add_video(
              internal_state :: internal_state_t,
              id :: id_t(),
              input_caps :: RawVideo.t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              z :: float()
            ) :: {:ok, internal_state_t} | {:error, error_t()}

  @doc """
  Video of the given `id` should be registered, removal of nonexistent video may cause undefined behaviour.
  """
  @callback remove_video(
              internal_state :: internal_state_t,
              id :: id_t()
            ) :: {:ok, internal_state_t} | {:error, error_t()}

  @doc """
  Video of the given `id` should be registered, using `id` of nonexistent video may cause undefined behaviour.
  `x` and `y` are pixel coordinates specifying where the top-right corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a lower `z` coordinate will cover videos with higher `z` coordinates.
  """
  @callback set_position(
              internal_state :: internal_state_t,
              id :: id_t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              z :: float()
            ) :: {:ok, internal_state_t} | {:error, error_t()}
end
