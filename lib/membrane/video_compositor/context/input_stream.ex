defmodule Membrane.LiveCompositor.Context.InputStream do
  @moduledoc """
  Context of single LiveCompositor input.
  """

  @enforce_keys [:id, :pad_ref]
  defstruct @enforce_keys

  @typedoc """
  Context of single LiveCompositor input.
  """
  @type t :: %__MODULE__{
          id: Membrane.LiveCompositor.input_id(),
          pad_ref: Membrane.Pad.ref()
        }
end
