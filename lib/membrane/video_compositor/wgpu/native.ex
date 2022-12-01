defmodule Membrane.VideoCompositor.Wgpu.Native do
  @moduledoc """
  Module with Rust NIFs - direct Rust communication.
  """
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_videocompositor"

  alias Membrane.VideoCompositor.RustStructs.{RawVideo, VideoLayout}

  @type wgpu_state() :: any()
  @type error_t() :: any()
  @type id_t() :: non_neg_integer()
  @type frame_with_pts() :: {binary(), Membrane.Time.t()}

  @spec init(RawVideo.t()) :: {:ok, wgpu_state()} | {:error, error_t()}
  def init(_out_video), do: error()

  @spec upload_frame(wgpu_state(), id_t(), binary(), Membrane.Time.t()) ::
          :ok | {:ok, frame_with_pts()} | {:error, atom()}
  def upload_frame(_state, _id, _frame, _pts), do: error()

  @spec force_render(wgpu_state()) :: {:ok, frame_with_pts()} | {:error, atom()}
  def force_render(_state), do: error()

  @spec add_video(wgpu_state(), id_t(), RawVideo.t(), VideoLayout.t()) ::
          :ok | {:error, error_t()}
  def add_video(_state, _id, _caps, _layout), do: error()

  @spec update_caps(wgpu_state(), id_t(), RawVideo.t()) :: :ok | {:error, error_t()}
  def update_caps(_state, _id, _caps), do: error()

  @spec update_layout(wgpu_state(), id_t(), VideoLayout.t()) :: :ok | {:error, error_t()}
  def update_layout(_state, _id, _layout), do: error()

  @spec remove_video(wgpu_state(), id_t()) ::
          :ok | {:error, error_t()}
  def remove_video(_state, _id), do: error()

  @spec send_end_of_stream(wgpu_state(), id_t()) :: :ok | {:error, atom()}
  def send_end_of_stream(_state, _id), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
