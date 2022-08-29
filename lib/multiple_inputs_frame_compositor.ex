defmodule Membrane.VideoCompositor.FrameCompositor.MultipleInputs do
  @moduledoc """
  This module defines behaviour for different frame composition implementations supporting multiple input frames.
  """
  alias Membrane.RawVideo

  @callback init(output_caps :: RawVideo.t()) :: {:ok, state :: any()}

  @callback merge_frames(
              frames :: [binary()],
              internal_state :: any()
            ) :: {{:ok, merged_frames :: binary()}, state :: any()}

  @callback add_video(
              id :: non_neg_integer(),
              input_caps :: RawVideo.t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()}
            ) :: {:ok, state :: any()}

  @callback remove_video(id :: non_neg_integer()) :: {:ok, state :: any()}

  @callback set_position(
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              id :: non_neg_integer()
            ) :: {:ok, state :: any()}
end
