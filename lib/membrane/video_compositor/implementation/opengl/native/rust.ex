defmodule Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust do
  @moduledoc false
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: :membrane_videocompositor_opengl_rust

  @type internal_state_t :: any()
  @type error_t :: any()
  @type id_t() :: non_neg_integer()

  @spec init(__MODULE__.RawVideo.t()) ::
          {:ok, internal_state_t()} | {:error, error_t()}
  def init(_out_video), do: error()

  @spec join_frames(internal_state_t(), [{id_t(), binary()}]) ::
          {:ok, binary()} | {:error, error_t()}
  def join_frames(_state, _frames), do: error()

  @spec add_video(internal_state_t(), id_t(), __MODULE__.RawVideo.t(), __MODULE__.Position.t()) ::
          :ok | {:error, error_t()}
  def add_video(_state, _id, _in_video, _position), do: error()

  @spec remove_video(internal_state_t(), id_t()) ::
          :ok | {:error, error_t()}
  def remove_video(_state, _id), do: error()

  @spec set_position(internal_state_t(), id_t(), __MODULE__.Position.t()) ::
          :ok | {:error, error_t()}
  def set_position(_state, _id, _position), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.RawVideo do
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

defmodule Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.Position do
  @moduledoc """
  A Position struct describing the video position for use with the rust-based compositor implementation
  """

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer()
        }

  @enforce_keys [:x, :y]
  defstruct [:x, :y]

  @spec from_tuple({non_neg_integer(), non_neg_integer()}) :: {:ok, __MODULE__.t()}
  def from_tuple({x, y}) do
    {:ok, %__MODULE__{x: x, y: y}}
  end
end
