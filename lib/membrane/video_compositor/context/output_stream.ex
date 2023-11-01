defmodule Membrane.VideoCompositor.Context.OutputStream do
  @moduledoc false

  alias Membrane.VideoCompositor

  @enforce_keys [:id, :pad_ref, :width, :height]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: VideoCompositor.output_id(),
          pad_ref: :not_linked | Membrane.Pad.ref(),
          width: Membrane.RawVideo.width_t(),
          height: Membrane.RawVideo.height_t()
        }
end
