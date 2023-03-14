defmodule Membrane.VideoCompositor.Scene.RustlerFriendly.InputVideo do
  @moduledoc false

  @type t :: %__MODULE__{
          input_pad: Membrane.Pad.ref_t()
        }

  @enforce_keys [:input_pad]
  defstruct @enforce_keys
end
