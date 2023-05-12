defmodule Membrane.VideoCompositor.Scene.VideoConfig do
  @moduledoc false

  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.VideoTransformations

  @enforce_keys [:placement]
  defstruct @enforce_keys ++ [transformations: VideoTransformations.empty()]

  @type t :: %__MODULE__{
          placement: BaseVideoPlacement.t(),
          transformations: VideoTransformations.t()
        }
end