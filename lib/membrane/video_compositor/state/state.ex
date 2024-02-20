defmodule Membrane.LiveCompositor.State do
  @moduledoc false

  @enforce_keys [:framerate, :lc_port]
  defstruct @enforce_keys ++ [inputs: [], outputs: [], server_pid: nil]

  @type t :: %__MODULE__{
          inputs: list(__MODULE__.Input.t()),
          outputs: list(__MODULE__.Output.t()),
          framerate: non_neg_integer(),
          lc_port: :inet.port_number(),
          server_pid: pid() | nil
        }

  @spec used_ports(t()) :: list(:inet.port_number())
  def used_ports(%__MODULE__{inputs: inputs, outputs: outputs, lc_port: lc_port}) do
    Enum.concat([inputs, outputs])
    |> Enum.map(fn pad_state -> pad_state.port end)
    |> Enum.concat([lc_port])
  end
end
