defmodule Membrane.VideoCompositor.Pipeline.Utils.InputStream do
  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          stream_format: Membrane.RawVideo.t(),
          placement: Membrane.VideoCompositor.Scene.BaseVideoPlacement,
          timestamp_offset: Membrane.Time.non_neg_t(),
          transformations: Membrane.VideoCompositor.VideoTransformations,
          input: String.t() | Membrane.Source
        }
  @enforce_keys [:stream_format, :placement, :transformations, :input]
  defstruct stream_format: nil,
            placement: nil,
            transformations: nil,
            timestamp_offset: 0,
            input: nil
end
