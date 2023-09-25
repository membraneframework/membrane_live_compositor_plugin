defmodule Membrane.VideoCompositor.Scene do
  @moduledoc false

  defstruct [:nodes, :outputs]

  @type node_spec :: map()
  @type output_spec :: %{
          output_id: Membrane.VideoCompositor.output_id(),
          input_pad: String.t()
        }

  @type t :: %__MODULE__{
          nodes: list(node_spec()),
          outputs: list(output_spec())
        }
end
