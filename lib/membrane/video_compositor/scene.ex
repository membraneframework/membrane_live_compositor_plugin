defmodule Membrane.VideoCompositor.Scene do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene.LayoutSpec
  alias Membrane.VideoCompositor.Scene.Object
  alias Membrane.VideoCompositor.Scene.TransformationSpec

  defstruct [:objects, :output, layouts: [], transformations: []]

  @type t :: %__MODULE__{
          transformations: [{Object.name_t(), TransformationSpec.definition_t()}],
          layouts: %{Object.name_t() => LayoutSpec.definition_t()},
          objects: [{Object.name_t(), Object.t()}],
          output: Object.name_t()
        }
end
