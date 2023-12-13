defmodule Membrane.VideoCompositor.State.Input do
  @moduledoc false

  @enforce_keys [:id, :pad_ref, :port]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: Membrane.VideoCompositor.input_id(),
          pad_ref: Membrane.Pad.ref(),
          port: :inet.port_number()
        }
end
