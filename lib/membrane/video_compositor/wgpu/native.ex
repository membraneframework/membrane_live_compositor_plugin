defmodule Membrane.VideoCompositor.Wgpu.Native do
  @moduledoc """
  Module with Rust NIFs - direct Rust communication.
  """

  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_videocompositor"

  alias Membrane.VideoCompositor.RustStructs

  @type wgpu_state() :: any()
  @type error() :: any()
  @type video_id() :: non_neg_integer()
  @type frame_with_pts() :: {binary(), Membrane.Time.t()}

  @spec init(RustStructs.RawVideo.t()) :: {:ok, wgpu_state()} | {:error, error()}
  def init(_out_video), do: error()

  @spec process_frame(wgpu_state(), video_id(), binary(), Membrane.Time.t()) ::
          :ok | {:ok, frame_with_pts()} | {:error, atom()}
  def process_frame(_state, _id, _frame, _pts), do: error()

  @spec set_videos(wgpu_state(), %{video_id() => RustStructs.RawVideo.t()}, RustStructs.Scene.t()) ::
          :ok | {:error, error()}
  def set_videos(_state, _stream_format, _scene), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
