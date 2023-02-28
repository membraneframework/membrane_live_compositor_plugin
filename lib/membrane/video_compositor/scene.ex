defmodule Membrane.VideoCompositor.Scene do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene.Object

  defstruct [:objects, :output, layouts: [], transformations: []]

  @type t :: %__MODULE__{
          objects: [{Object.name_t(), Object.t()}],
          output: Object.name_t()
        }
end
