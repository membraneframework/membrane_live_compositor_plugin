defmodule Membrane.VideoCompositor.Queue.Strategy.Offline.State do
  @moduledoc false

  alias Membrane.Pad

  defstruct inputs_mapping: %{}

  @type t :: %__MODULE__{
          inputs_mapping: %{(queue_input :: Pad.ref()) => vc_input :: Pad.ref()}
        }
end
