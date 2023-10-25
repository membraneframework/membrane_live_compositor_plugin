defmodule Membrane.VideoCompositor.InputState do
  @moduledoc """
  State of single input stream.
  """

  @enforce_keys [:input_id, :pad_ref, :port_number]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          input_id: Membrane.VideoCompositor.input_id(),
          pad_ref: Membrane.Pad.ref()
        }
end
