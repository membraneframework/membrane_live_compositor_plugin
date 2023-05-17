defmodule Membrane.VideoCompositor.Scene.VideoConfig do
  @moduledoc """
  Structure representing a specification of how Video Compositor
  should transform single input video.
  """

  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.VideoTransformations

  @enforce_keys [:placement]
  defstruct @enforce_keys ++ [transformations: VideoTransformations.empty()]

  @typedoc """
  Describe video base placement and transformations.

  For more information view `#{Membrane.VideoCompositor.RustStructs.BaseVideoPlacement}` and `#{Membrane.VideoCompositor.VideoTransformations}`.
  """
  @type t :: %__MODULE__{
          placement: BaseVideoPlacement.t(),
          transformations: VideoTransformations.t()
        }
end
