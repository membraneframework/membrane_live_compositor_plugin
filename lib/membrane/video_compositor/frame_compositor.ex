defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations, supporting multiple input frames.
  """
  alias Membrane.RawVideo

  @type id_t() :: non_neg_integer()
  @type internal_state_t() :: any()
  @type error_t() :: any()
  @type frame_t() :: binary()
  @type pts_t() :: Membrane.Time.t()
  @type frame_with_pts_t :: {binary(), pts_t()}

  @callback init(output_caps :: RawVideo.t()) :: {:ok, internal_state_t} | {:error, error_t()}

  @doc """
  Uploads a frame to the compositor.

  If all videos have provided input frames with a current enough pts, this will also render and return a composed frame.
  """
  @callback upload_frame(internal_state_t(), id_t(), frame_with_pts_t()) ::
              {:ok | {:ok, frame_with_pts_t()}, internal_state_t()}

  @doc """
  Forcibly renders the composed frame, even if we are still waiting for some frames to arrive
  """
  @callback force_render(internal_state :: internal_state_t) ::
              {{:ok, merged_frames :: frame_with_pts_t()}, internal_state_t} | {:error, error_t()}

  @doc """
  Registers a new input video with the given numerical `id`.

  Provided `id` should be unique within all previous ones, otherwise the compositor may or may not replace
  the old video with this id with a new one.
  `x` and `y` are pixel coordinates specifying where the top-left corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a higher `z` coordinate will cover videos with lower `z` coordinates.
  """
  @callback add_video(
              internal_state :: internal_state_t,
              id :: id_t(),
              input_caps :: RawVideo.t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              z :: float(),
              scale :: float()
            ) :: {:ok, internal_state_t} | {:error, error_t()}

  @doc """
  If the video doesn't exist this will return an error.
  """
  @callback remove_video(
              internal_state :: internal_state_t,
              id :: id_t()
            ) :: {:ok, internal_state_t} | {:error, error_t()}

  @doc """
  Send an end of stream to a video with the given `id`.

  This causes the video to be deleted after it's enqueued frames are used up.
  """
  @callback send_end_of_stream(internal_state_t(), id_t()) ::
              {:ok, internal_state_t()} | {:error, error_t()}

  @doc """
  `x` and `y` are pixel coordinates specifying where the top-left corner of the video should be.
  `z` must be a float between 0.0 and 1.0, and it determines which videos are drawn in front of others.
  A video with a higher `z` coordinate will cover videos with lower `z` coordinates.
  """
  @callback set_properties(
              internal_state :: internal_state_t,
              id :: id_t(),
              position :: {x :: non_neg_integer(), y :: non_neg_integer()},
              z :: float(),
              scale :: float()
            ) :: {:ok, internal_state_t} | {:error, error_t()}
end
