defmodule Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust do
  @moduledoc false
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: :membrane_videocompositor_opengl_rust

  alias Membrane.VideoCompositor.Implementations.Common.{Position, RawVideo}

  @type internal_state_t :: any()
  @type error_t :: any()
  @type id_t() :: non_neg_integer()

  @spec init(RawVideo.t()) ::
          {:ok, internal_state_t()} | {:error, error_t()}
  def init(_out_video), do: error()

  @spec join_frames(internal_state_t(), [{id_t(), binary()}]) ::
          {:ok, binary()} | {:error, error_t()}
  def join_frames(_state, _frames), do: error()

  @spec add_video(internal_state_t(), id_t(), RawVideo.t(), Position.t()) ::
          :ok | {:error, error_t()}
  def add_video(_state, _id, _in_video, _position), do: error()

  @spec remove_video(internal_state_t(), id_t()) ::
          :ok | {:error, error_t()}
  def remove_video(_state, _id), do: error()

  @spec set_position(internal_state_t(), id_t(), Position.t()) ::
          :ok | {:error, error_t()}
  def set_position(_state, _id, _position), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
