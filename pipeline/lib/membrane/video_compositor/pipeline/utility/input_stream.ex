defmodule Membrane.VideoCompositor.Pipeline.Utility.InputStream do
  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          caps: Membrane.RawVideo.t(),
          id: non_neg_integer(),
          input: String.t() | Membrane.Source
        }
  @enforce_keys [:caps, :id, :input]
  defstruct caps: nil, id: nil, input: nil
end
