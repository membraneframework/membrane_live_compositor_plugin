defmodule Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust do
  @moduledoc false
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: :membrane_videocompositor_opengl_rust

  @spec init(__MODULE__.RawVideo.t(), __MODULE__.RawVideo.t(), __MODULE__.RawVideo.t()) ::
          {:ok, any} | {:error, any}
  def init(_first_video, _second_video, _out_video), do: error()

  @spec join_frames(any, binary(), binary()) :: {:ok, binary()} | {:error, any}
  def join_frames(_state, _upper, _lower), do: error()

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
          width: pos_integer(),
          height: pos_integer(),
          pixel_format: pixel_format_t()
        }

  @enforce_keys [:width, :height, :pixel_format]
  defstruct [:width, :height, :pixel_format]
end
