defmodule Membrane.VideoCompositor.Context do
  @moduledoc """
  Context of VideoCompositor.
  """

  alias Membrane.VideoCompositor.{InputState, OutputState}

  @enforce_keys [:inputs, :outputs]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs: list(InputState.t()),
          outputs: list(OutputState.t())
        }
end
