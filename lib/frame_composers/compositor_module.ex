defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations.
  """
  alias Membrane.RawVideo

  @callback init(caps :: RawVideo) :: {:ok, any}
  @callback merge_frames(
              frames :: %{
                first: binary(),
                second: binary()
              },
              caps :: %RawVideo{}
            ) :: {:ok, bitstring()}
end
