defmodule Membrane.VideoCompositor.Implementations.Wgpu.Native do
  @moduledoc false
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_videocompositor_wgpu"

  alias Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.RawVideo

  @spec init(RawVideo.t(), RawVideo.t(), RawVideo.t()) :: {:ok, any()} | {:error, any}
  def init(_first_video, _second_video, _out_video), do: error()

  @spec join_frames(any(), binary(), binary()) :: {:ok, binary()} | {:error, any()}
  def join_frames(_state, _upper, _lower), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
