defmodule Membrane.VideoCompositor.Implementation.FFmpeg.Native do
  @moduledoc false
  use Unifex.Loader
end

defmodule Membrane.VideoCompositor.Implementation.FFmpeg.Native.RawVideo do
  @moduledoc """
  Unifex compatible implementation of Membrane.RawVideo struct.
  It should be used only with the native FFmpeg module functions.
  """

  @typedoc """
  Currently supported formats used to encode the color of every pixel in each video frame.
  """
  @type pixel_format_t ::
          :I420 | :I422 | :I444

  @typedoc """
  Width of single frame in pixels.
  """
  @type width_t :: pos_integer()

  @typedoc """
  Height of single frame in pixels.
  """
  @type height_t :: pos_integer()

  @typedoc """
  Numerator of number of frames per second. To avoid using tuple type,
  it is described by 2 separate integers number.
  """
  @type framerate_num_t :: non_neg_integer

  @typedoc """
  Denominator of number of frames per second. To avoid using tuple type,
  it is described by 2 separate integers number. Default value is 1.
  """
  @type framerate_den_t :: pos_integer

  @type t :: %__MODULE__{
          width: width_t(),
          height: height_t(),
          pixel_format: pixel_format_t(),
          framerate_num: framerate_num_t(),
          framerate_den: framerate_den_t()
        }
  @enforce_keys [:width, :height, :pixel_format, :framerate_num]
  defstruct width: nil, height: nil, pixel_format: nil, framerate_num: nil, framerate_den: 1

  @supported_pixel_formats [:I420, :I422, :I444]

  @doc """
  Creates unifex compatible struct from Membrane.RawVideo struct.
  It may result in error when RawVideo with not supported pixel format is provided.
  """
  @spec from_membrane_raw_video(Membrane.RawVideo.t()) ::
          {:ok, __MODULE__.t()} | {:error, :not_supported_pixel_format}

  def from_membrane_raw_video(%Membrane.RawVideo{pixel_format: format} = raw_video)
      when format in @supported_pixel_formats do
    {framerate_num, framerate_den} = raw_video.framerate

    {:ok,
     %__MODULE__{
       width: raw_video.width,
       height: raw_video.height,
       pixel_format: raw_video.pixel_format,
       framerate_num: framerate_num,
       framerate_den: framerate_den
     }}
  end

  def from_membrane_raw_video(_raw_video) do
    {:error, :not_supported_pixel_format}
  end
end
