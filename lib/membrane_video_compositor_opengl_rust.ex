defmodule Membrane.VideoCompositor.OpenGL.Rust do
  use Rustler,
    otp_app: :membrane_video_compositor_plugin,
    crate: :membrane_videocompositor_opengl_rust

  def init(_first_video, _second_video, _out_video), do: error()
  def join_frames(_upper, _lower), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule Membrane.VideoCompositor.OpenGL.Rust.RawVideo do
  @enforce_keys [:width, :height, :pixel_format]
  defstruct [:width, :height, :pixel_format]
end
