defmodule Membrane.VideoCompositor.Queue.Offline.State do
  @moduledoc false

  alias Membrane.Pad

  defstruct inputs_mapping: %{}

  @type t :: %__MODULE__{
          inputs_mapping: %{(queue_input :: Pad.ref_t()) => vc_input :: Pad.ref_t()}
        }
end
