defmodule Membrane.VideoCompositor.VideoConfig do
  @moduledoc """
  Structure representing a specification of how Video Compositor
  should transform single input video.
  """

  alias Membrane.VideoCompositor.BaseVideoPlacement
  alias Membrane.VideoCompositor.Transformations

  @enforce_keys [:placement]
  defstruct @enforce_keys ++ [transformations: []]

  @typedoc """
  Describe video base placement and transformations.

  For more information view `#{Membrane.VideoCompositor.BaseVideoPlacement}` and `#{Membrane.VideoCompositor.Transformations}`.
  """
  @type t :: %__MODULE__{
          placement: BaseVideoPlacement.t(),
          transformations: [Transformations.t()]
        }
end
