defmodule Membrane.LiveCompositor.Context.OutputStream do
  @moduledoc """
  Context of single LiveCompositor output.
  """

  alias Membrane.LiveCompositor

  @enforce_keys [:id, :pad_ref, :width, :height]
  defstruct @enforce_keys

  @typedoc """
  Context of single LiveCompositor output.
  """
  @type t :: %__MODULE__{
          id: LiveCompositor.output_id(),
          pad_ref: :not_linked | Membrane.Pad.ref(),
          width: Membrane.RawVideo.width_t(),
          height: Membrane.RawVideo.height_t()
        }
end
