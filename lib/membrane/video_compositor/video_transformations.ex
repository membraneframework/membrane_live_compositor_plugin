defmodule Membrane.VideoCompositor.VideoTransformations do
  @moduledoc """
  Describes transformations applied to single video.
  """

  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations

  @typedoc """
  Describes all transformations applied to video.
  Order of transformations matters. Transformations are
  applied in order in which they appear in the list.
  """
  @type t :: %__MODULE__{
          texture_transformations: list(TextureTransformations.t())
        }

  @enforce_keys [:texture_transformations]
  defstruct @enforce_keys

  @spec get_empty_video_transformations :: Membrane.VideoCompositor.VideoTransformations.t()
  def get_empty_video_transformations() do
    %VideoTransformations{
      texture_transformations: []
    }
  end
end
