defmodule Membrane.VideoCompositor.VideoTransformations do
  @moduledoc """
  Describes all transformations applied to the video.
  Order of transformations matters. Transformations are
  applied in the order in which they appear in the list.
  """

  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations

  @type t :: %__MODULE__{
          texture_transformations: list(TextureTransformations.t())
        }

  @enforce_keys [:texture_transformations]
  defstruct @enforce_keys

  @spec empty :: Membrane.VideoCompositor.VideoTransformations.t()
  def empty() do
    %VideoTransformations{
      texture_transformations: []
    }
  end
end
