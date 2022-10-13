defmodule Membrane.VideoCompositor.Wgpu.Native do
  @moduledoc false
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_videocompositor_wgpu"

  alias Membrane.VideoCompositor.Common.{Position, RawVideo}

  @type internal_state_t :: any()
  @type error_t :: any()
  @type id_t() :: non_neg_integer()

  @spec init(RawVideo.t()) :: {:ok, internal_state_t()} | {:error, error_t()}
  def init(_out_video), do: error()

  @spec render_frame(internal_state_t(), [{id_t(), binary()}]) ::
          {:ok, binary()} | {:error, error_t()}
  def render_frame(_state, _input_videos), do: error()

  @spec add_video(internal_state_t(), id_t(), RawVideo.t(), Position.t()) ::
          :ok | {:error, error_t()}
  def add_video(_state, _id, _in_video, _position), do: error()

  @spec set_position(internal_state_t(), id_t(), Position.t()) ::
          :ok | {:error, error_t()}
  def set_position(_state, _id, _position), do: error()

  @spec remove_video(internal_state_t(), id_t()) ::
          :ok | {:error, error_t()}
  def remove_video(_state, _id), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
