defmodule Membrane.VideoCompositor.Pipeline.Utils.InputStream do
  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          caps: Membrane.RawVideo.t(),
          layout: Membrane.VideoCompositor.RustStructs.VideoLayout,
          input: String.t() | Membrane.Source
        }
  @enforce_keys [:caps, :layout, :input]
  defstruct caps: nil, layout: nil, input: nil
end
