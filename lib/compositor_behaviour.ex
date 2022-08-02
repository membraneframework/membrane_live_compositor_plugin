defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations.
  """
  alias Membrane.RawVideo

  @callback init(caps :: RawVideo) :: {:ok, state :: any()}
  @callback merge_frames(
              frames :: %{
                first: binary(),
                second: binary()
              },
              state_of_init_module :: any()
            ) :: {:ok, merged_frames :: binary(), state :: any()}
end
