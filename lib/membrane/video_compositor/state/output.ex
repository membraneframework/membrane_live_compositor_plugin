defmodule Membrane.LiveCompositor.State.Output do
  @moduledoc false

  @enforce_keys [:id, :port, :width, :height]
  defstruct @enforce_keys ++ [pad_ref: :not_linked, ssrc: :stream_not_received]

  @type t :: %__MODULE__{
          id: Membrane.LiveCompositor.output_id(),
          width: Membrane.RawVideo.width_t(),
          height: Membrane.RawVideo.height_t(),
          port: :inet.port_number(),
          pad_ref: :not_linked | Membrane.Pad.ref(),
          ssrc: :stream_not_received | Membrane.RTP.ssrc_t()
        }
end
