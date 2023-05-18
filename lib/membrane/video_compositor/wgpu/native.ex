defmodule Membrane.VideoCompositor.Wgpu.Native do
  @moduledoc false
  # Module with Rust NIFs - direct Rust communication.

  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_videocompositor"

  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.RustStructs.{BaseVideoPlacement, RawVideo}
  alias Membrane.VideoCompositor.Scene.BaseVideoPlacement

  @type wgpu_state() :: any()
  @type error() :: any()
  @type id() :: non_neg_integer()
  @type frame_with_pts() :: {binary(), Membrane.Time.t()}

  @spec init(RawVideo.t()) :: {:ok, wgpu_state()} | {:error, error()}
  def init(_out_video), do: error()

  @spec process_frame(wgpu_state(), id(), binary(), Membrane.Time.t()) ::
          :ok | {:ok, frame_with_pts()} | {:error, atom()}
  def process_frame(_state, _id, _frame, _pts), do: error()

  @spec force_render(wgpu_state()) :: {:ok, frame_with_pts()} | {:error, atom()}
  def force_render(_state), do: error()

  @spec add_video(
          wgpu_state(),
          id(),
          RawVideo.t(),
          BaseVideoPlacement.t(),
          VideoTransformations.t()
        ) ::
          :ok | {:error, error()}
  def add_video(_state, _id, _stream_format, _placement, _transformations), do: error()

  @spec update_stream_format(wgpu_state(), id(), RawVideo.t()) :: :ok | {:error, error()}
  def update_stream_format(_state, _id, _stream_format), do: error()

  @spec update_placement(wgpu_state(), id(), BaseVideoPlacement.t()) ::
          :ok | {:error, error()}
  def update_placement(_state, _id, _placement), do: error()

  @spec update_transformations(wgpu_state(), id(), VideoTransformations.t()) ::
          :ok | {:error, error()}
  def update_transformations(_state, _id, _transformations), do: error()

  @spec remove_video(wgpu_state(), id()) ::
          :ok | {:error, error()}
  def remove_video(_state, _id), do: error()

  @spec send_end_of_stream(wgpu_state(), id()) :: {:ok, [frame_with_pts()]} | {:error, atom()}
  def send_end_of_stream(_state, _id), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
