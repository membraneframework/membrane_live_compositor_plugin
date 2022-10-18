defmodule Membrane.VideoCompositor.Common.RawVideo do
  @moduledoc """
  A RawVideo struct describing the video format for use with the rust-based compositor implementation
  """

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
  defstruct [:width, :height, :pixel_format, :framerate]

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

defmodule Membrane.VideoCompositor.Common.Position do
  @moduledoc """
  A Position struct describing the video position for use with the rust-based compositor implementation.
  Position relative to the top right corner of the viewport, in pixels.
  The `z` value specifies priority: a lower `z` is 'in front' of higher `z` values.
  """

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          z: float(),
          scale: float()
        }

  @enforce_keys [:x, :y, :z, :scale]
  defstruct [:x, :y, z: 0.0, scale: 1.0]

  @spec from_tuple({non_neg_integer(), non_neg_integer(), float(), float()}) ::
          {:ok, __MODULE__.t()} | {:error, atom()}
  def from_tuple({x, y, z, scale}) do
    if z < 0.0 or z > 1.0 do
      {:error, :z_out_of_range}
    else
      {:ok, %__MODULE__{x: x, y: y, z: z, scale: scale}}
    end
  end
end
