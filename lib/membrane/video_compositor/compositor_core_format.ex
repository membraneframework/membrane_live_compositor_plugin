defmodule Membrane.VideoCompositor.CompositorCoreFormat do
  @moduledoc """
  Describes CoreVC input format.
  """

  alias Membrane.{Pad, RawVideo}

  @enforce_keys [:pads_formats]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          pads_formats: %{Pad.ref_t() => RawVideo.t()}
        }
end
