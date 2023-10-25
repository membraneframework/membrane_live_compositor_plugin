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
