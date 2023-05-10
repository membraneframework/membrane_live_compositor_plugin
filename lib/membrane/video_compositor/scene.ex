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

  defmodule MockCallbacks do
    @moduledoc false

    @spec add_video(Scene.t(), Pad.ref_t(), %{:video_config => VideoConfig.t()}) :: Scene.t()
    def add_video(current_scene, added_pad, %{video_config: video_config}) do
      Map.put(current_scene, added_pad, video_config)
    end

    @spec remove_video(Scene.t(), Pad.ref_t()) :: Scene.t()
    def remove_video(current_scene, removed_pad) do
      Map.delete(current_scene, removed_pad)
    end
  end
end
