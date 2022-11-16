defmodule Membrane.VideoCompositor.Pipeline.Utils.InputStream do
  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          caps: Membrane.RawVideo.t(),
          position: {non_neg_integer(), non_neg_integer()},
          input: String.t() | Membrane.Source
        }
  @enforce_keys [:caps, :position, :input]
  defstruct caps: nil, position: nil, input: nil
end
