defmodule Membrane.VideoCompositor.Implementations do
  @moduledoc """
  A module describing multiple input video compositor implementation type and implementing
  functions related with implementation format.
  """

  @typedoc "Define video compositor implementation types"
  @type implementation_t :: :wgpu

  @spec get_implementation_module(implementation_t) :: {:ok, module()} | {:error, String.t()}
  def get_implementation_module(implementation) do
    case implementation do
      :wgpu ->
        {:ok, Membrane.VideoCompositor.Wgpu}

      _other ->
        {:error, "Format not supported"}
    end
  end

  @spec get_all_implementations() :: list(implementation_t)
  def get_all_implementations() do
    [:wgpu]
  end

  @spec get_implementation_atom_from_string(String.t()) :: implementation_t()
  def get_implementation_atom_from_string(implementation_string)
      when is_binary(implementation_string) do
    case implementation_string do
      "wgpu" -> :wgpu
    end
  end
end
