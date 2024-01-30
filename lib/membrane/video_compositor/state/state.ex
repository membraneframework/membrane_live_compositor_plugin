defmodule Membrane.LiveCompositor.State do
  @moduledoc false

  alias Membrane.LiveCompositor

  @enforce_keys [:framerate, :lc_port, :port_range]
  defstruct @enforce_keys ++ [inputs: [], outputs: []]

  @type t :: %__MODULE__{
          inputs: list(__MODULE__.Input.t()),
          outputs: list(__MODULE__.Output.t()),
          framerate: non_neg_integer(),
          lc_port: :inet.port_number(),
          port_range: LiveCompositor.port_range()
        }

  @spec used_ports(t()) :: list(:inet.port_number())
  def used_ports(%__MODULE__{inputs: inputs, outputs: outputs, lc_port: lc_port}) do
    Enum.concat([inputs, outputs])
    |> Enum.map(fn pad_state -> pad_state.port end)
    |> Enum.concat([lc_port])
  end
end
