defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementation.
  """
  alias Membrane.RawVideo

  @callback init(caps :: RawVideo.t()) :: {:ok, state :: any()}
  @callback merge_frames(
              frames :: %{
                first: binary(),
                second: binary()
              },
              internal_state :: any()
            ) :: {{:ok, merged_frames :: binary()}, state :: any()}
end
