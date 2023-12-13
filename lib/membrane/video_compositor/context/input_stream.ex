defmodule Membrane.VideoCompositor.Context.InputStream do
  @moduledoc """
  Context of single VideoCompositor input.
  """

  @enforce_keys [:id, :pad_ref]
  defstruct @enforce_keys

  @typedoc """
  Context of single VideoCompositor input.
  """
  @type t :: %__MODULE__{
          id: Membrane.VideoCompositor.input_id(),
          pad_ref: Membrane.Pad.ref()
        }
end
