defmodule Membrane.VideoCompositor.Scene do
  @moduledoc false

  defstruct [:nodes, :outputs]

  @type node_spec :: map()
  @type output :: %{
          output_id: Membrane.VideoCompositor.output_id(),
          input_pad: node_spec()
        }

  @type t :: %__MODULE__{
          nodes: list(node_spec()),
          outputs: list(output())
        }
end
