defmodule Membrane.VideoCompositor.State do
  @moduledoc false

  alias Membrane.VideoCompositor.{Context, InputState, OutputState}

  @enforce_keys [:inputs, :outputs, :framerate, :vc_port]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs: list(InputState.t()),
          outputs: list(OutputState.t()),
          framerate: non_neg_integer(),
          vc_port: :inet.port_number()
        }

  @spec ctx(t()) :: Membrane.VideoCompositor.Context.t()
  def ctx(%__MODULE__{inputs: inputs, outputs: outputs}) do
    %Context{
      inputs: inputs,
      outputs: outputs
    }
  end

  @spec used_ports(t()) :: MapSet.t()
  def used_ports(%__MODULE__{inputs: inputs, outputs: outputs, vc_port: vc_port}) do
    input_ports =
      inputs |> Enum.map(fn input_state -> input_state.port_number end) |> MapSet.new()

    output_ports =
      outputs |> Enum.map(fn output_state -> output_state.port_number end) |> MapSet.new()

    MapSet.new([vc_port]) |> MapSet.union(input_ports) |> MapSet.union(output_ports)
  end
end
