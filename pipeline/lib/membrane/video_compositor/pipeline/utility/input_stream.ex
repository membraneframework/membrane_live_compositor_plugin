defmodule Membrane.VideoCompositor.Pipeline.Utils.InputStream do

  alias Membrane.{Time, RawVideo, Source}
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @doc """
  Specification of input video stream for a testing pipeline
  """
  @type t() :: %__MODULE__{
          input: String.t() | Source,
          timestamp_offset: Time.non_neg_t(),
          video_config: VideoConfig.t(),
          stream_format: RawVideo.t()
        }

  @enforce_keys [:input, :stream_format, :video_config]
  defstruct @enforce_keys ++ [timestamp_offset: 0]
end
