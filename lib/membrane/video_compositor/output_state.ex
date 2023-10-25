defmodule Membrane.VideoCompositor.OutputState do
  @moduledoc """
  State of single output stream.
  """

  @enforce_keys [:output_id, :pad_ref, :port_number, :resolution]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          output_id: Membrane.VideoCompositor.output_id(),
          pad_ref: Membrane.Pad.ref(),
          port_number: :inet.port_number(),
          resolution: Membrane.VideoCompositor.Resolution.t()
        }
end
