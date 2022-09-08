defmodule Membrane.VideoCompositor.MultipleInputs.VideoCompositor.Implementations do
  @moduledoc """
  A module describing multiple input video compositor implementation type and implementing
  functions related with implementation format.
  """

  @typedoc "Define video compositor implementation types"
  @type implementation_t :: :ffmpeg | :opengl_cpp | :opengl_rust | :nx

  @spec get_implementation_module(implementation_t) :: {:ok, module()} | {:error, String.t()}
  def get_implementation_module(implementation) do
    case implementation do
      :ffmpeg ->
        raise ":ffmpeg is not implemented yet"

      :opengl_cpp ->
        raise ":opengl_cpp is not implemented yet"

      :opengl_rust ->
        raise ":opengl_rust is not implemented yet"

      :nx ->
        raise ":nx is not implemented yet"

      _other ->
        {:error, "Format not supported"}
    end
  end

  @spec get_all_implementations() :: list(implementation_t)
  def get_all_implementations() do
    []
  end

  @spec get_implementation_atom_from_string(String.t()) :: implementation_t()
  def get_implementation_atom_from_string(implementation_string)
      when is_binary(implementation_string) do
    case implementation_string do
      "ffmpeg" -> :ffmpeg
      "opengl_cpp" -> :opengl_cpp
      "opengl_rust" -> :opengl_rust
      "nx" -> :nx
    end
  end
end
