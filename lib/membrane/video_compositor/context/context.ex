defmodule Membrane.VideoCompositor.Context do
  @moduledoc """
  Context of VideoCompositor. Specifies VideoCompositor inputs and outputs.
  """

  alias Membrane.VideoCompositor.State

  @enforce_keys [:inputs, :outputs]
  defstruct @enforce_keys

  @typedoc """
  Context of VideoCompositor. Specifies VideoCompositor inputs and outputs.
  """
  @type t :: %__MODULE__{
          inputs: list(__MODULE__.InputStream.t()),
          outputs: list(__MODULE__.OutputStream.t())
        }

  @doc false
  @spec new(State.t()) :: t()
  def new(state) do
    inputs =
      state.inputs
      |> Enum.map(fn %State.Input{id: id, pad_ref: pad_ref} ->
        %__MODULE__.InputStream{id: id, pad_ref: pad_ref}
      end)

    outputs =
      state.outputs
      |> Enum.map(fn %State.Output{id: id, pad_ref: pad_ref, width: width, height: height} ->
        %__MODULE__.OutputStream{id: id, pad_ref: pad_ref, width: width, height: height}
      end)

    %__MODULE__{
      inputs: inputs,
      outputs: outputs
    }
  end
end
