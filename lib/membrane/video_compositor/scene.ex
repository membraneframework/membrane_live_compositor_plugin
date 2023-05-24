defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @derive [Membrane.EventProtocol]
  @enforce_keys [:video_configs]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          video_configs: %{Pad.ref_t() => VideoConfig.t()}
        }

  @spec empty() :: t()
  def empty() do
    %Scene{video_configs: %{}}
  end
end
