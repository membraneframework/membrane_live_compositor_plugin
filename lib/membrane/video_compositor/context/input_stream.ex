defmodule Membrane.VideoCompositor.Context.InputStream do
  @moduledoc false

  @enforce_keys [:id, :pad_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: Membrane.VideoCompositor.input_id(),
          pad_ref: Membrane.Pad.ref()
        }
end
