defmodule Membrane.VideoCompositor.OutputState do
  @moduledoc """
  State of single output stream.
  """

  alias Membrane.VideoCompositor

  defstruct [:output_id, :pad_ref, :port_number, :resolution]

  @type t :: %__MODULE__{
          output_id: Membrane.VideoCompositor.output_id(),
          pad_ref: Membrane.Pad.ref(),
          port_number: :inet.port_number(),
          resolution: VideoCompositor.Resolution.t()
        }
end
