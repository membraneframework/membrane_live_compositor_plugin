defmodule Membrane.VideoCompositor.Implementations.Common.RawVideo do
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
          pixel_format: pixel_format_t()
        }

  @enforce_keys [:width, :height, :pixel_format]
  defstruct [:width, :height, :pixel_format]

  @spec from_membrane_raw_video(Membrane.RawVideo.t()) :: {:ok, __MODULE__.t()}
  def from_membrane_raw_video(%Membrane.RawVideo{} = raw_video) do
    {:ok,
     %__MODULE__{
       width: raw_video.width,
       height: raw_video.height,
       pixel_format: raw_video.pixel_format
     }}
  end
end

defmodule Membrane.VideoCompositor.Implementations.Common.Position do
  @moduledoc """
  A Position struct describing the video position for use with the rust-based compositor implementation.
  Position relative to the top right corner of the viewport, in pixels.
  """

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer()
        }

  @enforce_keys [:x, :y]
  defstruct [:x, :y]

  @spec from_tuple({non_neg_integer(), non_neg_integer()} | Membrane.VideoCompositor.Position.t()) ::
          {:ok, __MODULE__.t()}
  def from_tuple({x, y}) do
    {:ok, %__MODULE__{x: x, y: y}}
  end

  def from_tuple(%Membrane.VideoCompositor.Position{x: x, y: y}) do
    {:ok, %__MODULE__{x: x, y: y}}
  end
end
