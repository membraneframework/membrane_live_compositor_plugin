defmodule Membrane.VideoCompositor.MultipleInputs.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations, supporting multiple input frames.
  """
  alias Membrane.RawVideo

  @type id_t() :: non_neg_integer()

  @callback init(output_caps :: RawVideo.t()) :: {:ok, state :: any()}

  @doc """
  Frames are provided as tuples `{id, frame}` and given in the proper order of rendering (typically in ascending order of ids).
  Providing frames with wrong ids may cause undefined behaviour.
  """
  @callback merge_frames(
              frames :: [{id_t, binary()}],
              internal_state :: any()
            ) :: {{:ok, merged_frames :: binary()}, state :: any()}

  @doc """
  Registers a new input video with the given numerical `id`.
  Provided `id` should be unique within all previous ones, otherwise function may cause undefined behaviour.
  """
  @callback add_video(
              id :: id_t(),
              input_caps :: RawVideo.t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              internal_state :: any()
            ) :: {:ok, state :: any()}

  @doc """
  Video of the given `id` should be registered, removal of nonexistent video may cause undefined behaviour.
  """
  @callback remove_video(
              id :: id_t(),
              internal_state :: any()
            ) :: {:ok, state :: any()}

  @doc """
  Video of the given `id` should be registered, using `id` of nonexistent video may cause undefined behaviour.
  """
  @callback set_position(
              id :: id_t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              internal_state :: any()
            ) :: {:ok, state :: any()}
end
