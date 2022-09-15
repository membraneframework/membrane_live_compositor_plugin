defmodule Membrane.VideoCompositor.Implementations do
  @moduledoc """
  A module describing video compositor implementation type and implementing
  functions related with implementation format.
  """

  @typedoc "Define video compositor implementation types"
  @type implementation_t :: :ffmpeg | :opengl_cpp | :opengl_rust | :nx | :wgpu

  @spec get_implementation_module(implementation_t) :: {:ok, module()} | {:error, String.t()}
  def get_implementation_module(implementation) do
    case implementation do
      :ffmpeg ->
        {:ok, Membrane.VideoCompositor.Implementations.FFmpeg}

      :opengl_cpp ->
        {:ok, Membrane.VideoCompositor.Implementations.OpenGL.Cpp}

      :opengl_rust ->
        {:ok, Membrane.VideoCompositor.Implementations.OpenGL.Rust}

      :nx ->
        {:ok, Membrane.VideoCompositor.Nx}

      :wgpu ->
        {:ok, Membrane.VideoCompositor.Wgpu}

      _other ->
        {:error, "Format not supported"}
    end
  end

  @spec get_test_implementations() :: list()
  def get_test_implementations() do
    test_implementations = [:ffmpeg, :nx, :wgpu]
    test_implementations
  end

  @spec get_all_implementations() :: list()
  def get_all_implementations() do
    [:ffmpeg, :opengl_cpp, :opengl_rust, :nx, :wgpu]
  end

  @spec get_implementation_atom_from_string(String.t()) :: implementation_t()
  def get_implementation_atom_from_string(implementation_string) do
    case implementation_string do
      "ffmpeg" -> :ffmpeg
      "opengl_cpp" -> :opengl_cpp
      "opengl_rust" -> :opengl_rust
      "nx" -> :nx
      "wgpu" -> :wgpu
    end
  end
end
