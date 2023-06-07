defmodule Membrane.VideoCompositor.Wgpu.Native do
  @moduledoc false
  # Module with Rust NIFs - direct Rust communication.

  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: "membrane_video_compositor"

  @type error() :: any()

  @opaque native_state() :: reference()
  @opaque wgpu_ctx() :: non_neg_integer()

  @spec test_scene_deserialization(Membrane.VideoCompositor.Scene.RustlerFriendly.t()) ::
          :ok | {:error, error()}
  def test_scene_deserialization(_scene), do: error()

  @spec init() :: {:ok, native_state()} | {:error, error()}
  def init(), do: error()

  @spec wgpu_ctx(native_state()) :: wgpu_ctx()
  def wgpu_ctx(_state), do: error()

  @spec register_transformation(
          native_state(),
          Membrane.VideoCompositor.Transformation.initialized_transformation()
        ) :: :ok | {:error, error()}
  def register_transformation(_state, _transformation), do: error()

  @spec register_layout(
          native_state(),
          Membrane.VideoCompositor.Object.Layout.initialized_layout()
        ) :: :ok | {:error, error()}
  def register_layout(_state, _layout), do: error()

  @spec mock_transformation(wgpu_ctx()) ::
          Membrane.VideoCompositor.Transformation.initialized_transformation()
  def mock_transformation(_wgpu_ctx), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
