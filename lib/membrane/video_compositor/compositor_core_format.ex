defmodule Membrane.VideoCompositor.CompositorCoreFormat do
  @moduledoc false

  alias Membrane.{Pad, RawVideo}

  @enforce_keys [:frames]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          frames: %{Pad.ref_t() => RawVideo.t()}
        }
end
