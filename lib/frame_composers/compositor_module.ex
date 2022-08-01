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
              state :: %{
                pads: map(),
                streams_state: map(),
                caps: RawVideo,
                compositor_module: :ffmpeg | :opengl | :nx,
                state_of_init_module: map()
              }
            ) :: {:ok, bitstring()}
end
