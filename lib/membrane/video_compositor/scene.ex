defmodule Membrane.VideoCompositor.Scene do
  @moduledoc false

  alias Membrane.VideoCompositor.{Object, Texture}
  alias Membrane.VideoCompositor.Object.Alternation

  @enforce_keys [:objects, :render]
  defstruct @enforce_keys ++ [alternations: [], layouts: []]

  @type t :: %__MODULE__{
          alternations: [{Alternation.name_t(), Alternation.definition_t()}],
          layouts: [{Layout.name_t(), Layout.definition_t()}],
          objects: [{Object.name_t(), Object.t()}],
          render: Texture
        }
end
