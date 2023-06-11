defmodule Membrane.VideoCompositor.Support.Pipeline.InputStream do
  @moduledoc false
  alias Membrane.{RawVideo, Source}

  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          input: String.t() | Source,
          timestamp_offset: Membrane.Time.non_neg_t(),
          stream_format: RawVideo.t(),
          metadata: any()
        }

  @enforce_keys [:input, :stream_format]
  defstruct @enforce_keys ++ [timestamp_offset: 0, metadata: nil]
end
