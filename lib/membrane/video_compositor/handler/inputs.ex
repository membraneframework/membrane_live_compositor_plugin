defmodule Membrane.VideoCompositor.Handler.Inputs do
  @moduledoc """
  Definition of all VC input videos used in composition.
  """

  alias __MODULE__.InputProperties
  alias Membrane.Pad

  @typedoc """
  Describe all VC input videos used in composition.
  """
  @type t :: %{Pad.ref_t() => InputProperties.t()}

  defmodule InputProperties do
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
end
