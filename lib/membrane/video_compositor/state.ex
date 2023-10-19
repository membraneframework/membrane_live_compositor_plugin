defmodule Membrane.VideoCompositor.Context do
  @moduledoc false

  alias Membrane.VideoCompositor.{InputState, OutputState}

  defstruct [:inputs, :outputs]

  @type t :: %__MODULE__{
          inputs: list(InputState.t()),
          outputs: list(OutputState.t())
        }
end

defmodule Membrane.VideoCompositor.State do
  @moduledoc false

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
end

defmodule Membrane.VideoCompositor.InputState do
  @moduledoc false

  defstruct [:input_id, :pad_ref]

  @type t :: %__MODULE__{
          input_id: Membrane.VideoCompositor.input_id(),
          pad_ref: Membrane.Pad.ref()
        }
end

defmodule Membrane.VideoCompositor.OutputState do
  @moduledoc false

  defstruct [:output_id, :pad_ref]

  @type t :: %__MODULE__{
          output_id: Membrane.VideoCompositor.output_id(),
          pad_ref: Membrane.Pad.ref()
        }
end
