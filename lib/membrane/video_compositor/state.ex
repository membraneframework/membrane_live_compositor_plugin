defmodule Membrane.VideoCompositor.State do
  @moduledoc false

  alias Membrane.VideoCompositor

  defstruct [:inputs, :outputs]

  @type t :: %__MODULE__{
          inputs: list(VideoCompositor.input_id()),
          outputs: list(VideoCompositor.output_id())
        }
end
