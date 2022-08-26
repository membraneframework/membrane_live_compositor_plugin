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

  @spec get_all_implementations() :: list()
  def get_all_implementations() do
    [:ffmpeg, :opengl_cpp, :opengl_rust, :nx]
  end

  @spec get_implementation_name(implementation_t) :: {:ok, String.t()} | {:error, String.t()}
  def get_implementation_name(implementation) do
    case implementation do
      :ffmpeg -> {:ok, "FFmpeg"}
      :opengl_cpp -> {:ok, "OpenGL C++"}
      :opengl_rust -> {:ok, "OpenGL Rust"}
      :nx -> {:ok, "Nx"}
      _other -> {:error, "Format not supported"}
    end
  end
end
