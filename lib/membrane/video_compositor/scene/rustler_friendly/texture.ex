defmodule Membrane.VideoCompositor.Scene.RustlerFriendly.Texture do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene.{Object, Resolution, Transformation}

  @type output_resolution ::
          {:resolution, Resolution.t()} | {:name, Object.name()} | :transformed_input_resolution

  @enforce_keys [:input]
  defstruct @enforce_keys ++ [transformations: [], resolution: :transformed_input_resolution]

  @type t :: %__MODULE__{
          input: Object.name(),
          # FIXME: change this to a list of opaque rust things
          transformations: [Transformation.rust_representation()],
          resolution: output_resolution()
        }
end
