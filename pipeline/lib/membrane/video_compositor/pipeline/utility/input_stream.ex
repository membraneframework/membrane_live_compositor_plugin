defmodule Membrane.VideoCompositor.Pipeline.Utility.InputStream do
  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          caps: Membrane.RawVideo.t(),
          position: {non_neg_integer(), non_neg_integer()},
          z_value: float(),
          scale: float(),
          input: String.t() | Membrane.Source
        }
  @enforce_keys [:caps, :position, :scale, :input]
  defstruct caps: nil, z_value: nil, position: nil, scale: nil, input: nil
end
