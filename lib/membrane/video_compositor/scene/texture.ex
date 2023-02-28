defmodule Membrane.VideoCompositor.Scene.Texture do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene.Object
  alias Membrane.VideoCompositor.Scene.Resolution
  alias Membrane.VideoCompositor.Scene.TransformationSpec

  @enforce_keys [:input, :transformations]
  defstruct @enforce_keys ++ [resolution: :transformed_input_resolution]

  @type t :: %__MODULE__{
          input: Object.name_t(),
          transformations: [TransformationSpec.definition_t()],
          resolution: Resolution.t() | :transformed_input_resolution
        }
end
