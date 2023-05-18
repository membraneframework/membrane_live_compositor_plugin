defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @enforce_keys [:videos_configs]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          videos_configs: %{Pad.ref_t() => VideoConfig.t()}
        }

  @spec empty() :: t()
  def empty() do
    %Scene{videos_configs: %{}}
  end
end
