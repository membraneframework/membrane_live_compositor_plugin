defmodule Membrane.VideoCompositor.MultipleInputs.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations supporting multiple input frames.
  """
  alias Membrane.RawVideo

  @type id_t() :: non_neg_integer()

  @callback init(output_caps :: RawVideo.t()) :: {:ok, state :: any()}

  @callback merge_frames(
              frames :: %{required(id_t) => binary()},
              internal_state :: any()
            ) :: {{:ok, merged_frames :: binary()}, state :: any()}

  @callback add_video(
              id :: id_t(),
              input_caps :: RawVideo.t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              internal_state :: any()
            ) :: {:ok, state :: any()}

  @callback remove_video(
              id :: id_t(),
              internal_state :: any()
            ) :: {:ok, state :: any()}

  @callback set_position(
              id :: id_t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              internal_state :: any()
            ) :: {:ok, state :: any()}
end
