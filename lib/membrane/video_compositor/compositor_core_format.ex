defmodule Membrane.VideoCompositor.CompositorCoreFormat do
  @moduledoc """
  Describes CoreVC input format.
  """

  alias Membrane.{Pad, RawVideo}

  @enforce_keys [:pad_formats]
  defstruct @enforce_keys

  @typedoc """
  Stream format of Queue - VC Core communication.
  Queue sends %{Pad.ref_t() => binary()} map in buffer
  payload and this format describes each frame resolution.
  """
  @type t :: %__MODULE__{
          pad_formats: %{Pad.ref_t() => RawVideo.t()}
        }
end
