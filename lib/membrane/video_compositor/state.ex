defmodule Membrane.VideoCompositor.Context do
  @moduledoc """
  Context of VideoCompositor.
  """

  alias Membrane.VideoCompositor.{InputState, OutputState}

  defstruct [:inputs, :outputs]

  @type t :: %__MODULE__{
          inputs: list(InputState.t()),
          outputs: list(OutputState.t())
        }
end

defmodule Membrane.VideoCompositor.State do
  @moduledoc false

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.{Context, InputState, OutputState}

  defstruct [:inputs, :outputs, :framerate, :vc_port]

  @type t :: %__MODULE__{
          inputs: list(InputState.t()),
          outputs: list(OutputState.t()),
          framerate: non_neg_integer(),
          vc_port: VideoCompositor.port_number()
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

defmodule Membrane.VideoCompositor.InputState do
  @moduledoc """
  State of single input stream.
  """

  defstruct [:input_id, :pad_ref, :port_number]

  @type t :: %__MODULE__{
          input_id: Membrane.VideoCompositor.input_id(),
          pad_ref: Membrane.Pad.ref()
        }
end

defmodule Membrane.VideoCompositor.OutputState do
  @moduledoc """
  State of single output stream.
  """

  defstruct [:output_id, :pad_ref, :port_number]

  @type t :: %__MODULE__{
          output_id: Membrane.VideoCompositor.output_id(),
          pad_ref: Membrane.Pad.ref()
        }
end
