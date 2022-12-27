defmodule Membrane.VideoCompositor.Pipeline.Utils.InputStream do
  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          caps: Membrane.RawVideo.t(),
          placement: Membrane.VideoCompositor.RustStructs.VideoPlacement,
          timestamp_offset: Membrane.Time.non_neg_t(),
          transformations: Membrane.VideoCompositor.VideoTransformations,
          input: String.t() | Membrane.Source
        }
  @enforce_keys [:caps, :placement, :transformations, :input]
  defstruct caps: nil, placement: nil, transformations: nil, timestamp_offset: 0, input: nil
end
