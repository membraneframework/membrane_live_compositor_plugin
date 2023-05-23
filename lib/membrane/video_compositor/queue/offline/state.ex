defmodule Membrane.VideoCompositor.Queue.Offline.State do
  @moduledoc false

  alias Membrane.Pad

  @enforce_keys [:inputs_mapping]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs_mapping: %{(queue_input :: Pad.ref_t()) => vc_input :: Pad.ref_t()}
        }

  @spec empty() :: Membrane.VideoCompositor.Queue.Offline.State.t()
  def empty() do
    %__MODULE__{
      inputs_mapping: %{}
    }
  end
end
