defmodule Membrane.VideoCompositor.RustStructs.RawVideo do
  @moduledoc false
  # A RawVideo struct describing the video format for use with the rust-based compositor.

  @typedoc """
  Pixel format of the video
  """
  @type pixel_format_t :: :I420

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          pixel_format: pixel_format_t(),
          framerate: {pos_integer(), pos_integer()}
        }

  @enforce_keys [:width, :height, :pixel_format, :framerate]
  defstruct @enforce_keys

  @spec from_membrane_raw_video(Membrane.RawVideo.t()) :: {:ok, __MODULE__.t()}
  def from_membrane_raw_video(%Membrane.RawVideo{} = raw_video) do
    {:ok,
     %__MODULE__{
       width: raw_video.width,
       height: raw_video.height,
       pixel_format: raw_video.pixel_format,
       framerate: raw_video.framerate
     }}
  end
end
