defmodule Membrane.VideoCompositor.FrameCompositor do
  @moduledoc """
  This module defines behaviour for different frame composition implementations.
  """
  alias Membrane.RawVideo

  @callback init(caps :: RawVideo) :: {:ok, any}
  @callback merge_frames(
              frame_binaries :: %{
                first_frame_binary: bitstring(),
                second_frame_binary: bitstring()
              },
              caps :: %RawVideo{}
            ) :: {:ok, bitstring()}
end
