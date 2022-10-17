defmodule Membrane.VideoCompositor.Wgpu.Native do
  @moduledoc false
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_videocompositor_wgpu"

  alias Membrane.VideoCompositor.Common.{Position, RawVideo}

  @type internal_state_t :: any()
  @type error_t :: any()
  @type id_t() :: non_neg_integer()
  @type frame_with_pts() :: {binary(), Membrane.Time.t()}

  @spec init(RawVideo.t()) :: {:ok, internal_state_t()} | {:error, error_t()}
  def init(_out_video), do: error()

  @spec upload_frame(internal_state_t(), id_t(), binary(), Membrane.Time.t()) ::
          :ok | {:ok, frame_with_pts()} | {:error, atom()}
  def upload_frame(_state, _id, _frame, _pts), do: error()

  @spec force_render(internal_state_t()) :: {:ok, frame_with_pts()} | {:error, atom()}
  def force_render(_state), do: error()

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
