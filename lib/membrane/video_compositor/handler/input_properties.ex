defmodule Membrane.VideoCompositor.Handler.InputProperties do
  @moduledoc """
  Defines properties of VC input video passed to callbacks.
  """
  alias Membrane.{RawVideo, VideoCompositor}

  @enforce_keys [:stream_format, :metadata]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          stream_format: RawVideo.t(),
          metadata: VideoCompositor.input_pad_metadata()
        }
end
