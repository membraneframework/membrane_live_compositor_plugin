defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Scene describes positions and transformations of the videos, provided to the video compositor.
  """

  alias Membrane.VideoCompositor.Scene.Video

  @type id_t :: non_neg_integer()

  @type t :: %__MODULE__{
          videos: %{}
        }
  defstruct videos: %{}

  @spec add_video(__MODULE__.t(), id_t(), Video.t()) :: __MODULE__.t()
  def add_video(scene, video_id, video) do
    %__MODULE__{scene | videos: Map.put_new(scene.videos, video_id, video)}
  end
end
