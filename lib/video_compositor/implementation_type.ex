defmodule Membrane.VideoCompositor.Implementation do
  @moduledoc """
  A module describing video compositor implementation type and implementing
  functions related with implementation format.
  """

  @typedoc "Define video compositor implementation types"
  @type implementation_t :: :ffmpeg | :opengl_cpp | :opengl_rust | :nx

  @spec get_implementation_module(implementation_t) :: {:ok, module()} | {:error, String.t()}
  def get_implementation_module(implementation) do
    case implementation do
      :ffmpeg ->
        {:ok, Membrane.VideoCompositor.FFmpeg}

      :opengl_cpp ->
        {:ok, Membrane.VideoCompositor.OpenGL.Cpp}

      :opengl_rust ->
        {:ok, Membrane.VideoCompositor.OpenGL.Rust}

      :nx ->
        {:ok, Membrane.VideoCompositor.Nx}

      _other ->
        {:error, "Format not supported"}
    end
  end

  @spec get_test_implementations() :: list()
  def get_test_implementations() do
    test_implementations = [:ffmpeg, :nx]
    test_implementations
  end

  @spec get_all_implementations() :: list()
  def get_all_implementations() do
    [:ffmpeg, :opengl_cpp, :opengl_rust, :nx]
  end

  def get_implementation_atom_from_string(implementation_string) do
    case implementation_string do
      "ffmpeg" -> :ffmpeg
      "opengl_cpp" -> :opengl_cpp
      "opengl_rust" -> :opengl_rust
      "nx" -> :nx
    end
  end
end
