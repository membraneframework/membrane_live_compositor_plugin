defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Scene describes positions and transformations of the videos, provided to the video compositor.
  """

  alias Membrane.VideoCompositor.Scene.Transformation
  alias Membrane.VideoCompositor.Scene.Video
  # alias Membrane.VideoCompositor.Scene.

  @type id_t :: non_neg_integer()

  @type t :: %__MODULE__{
          videos: %{required(id_t()) => Video.t()},
          transformations: keyword(Transformation.t()),
          components: %{required(atom()) => any()}
        }
  defstruct videos: %{}, components: %{}, transformations: []

  @spec add_video(__MODULE__.t(), id_t(), Video.t()) :: __MODULE__.t()
  def add_video(scene, video_id, video) do
    %__MODULE__{scene | videos: Map.put_new(scene.videos, video_id, video)}
  end

  defp update_videos(videos, time) do
    Enum.reduce_while(
      videos,
      {:ok, videos},
      fn {id, video}, {:ok, videos} ->
        case Video.update(video, time) do
          {:ok, video} -> {:cont, {:ok, Map.put(videos, id, video)}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end
    )
  end

  @spec update(__MODULE__.t(), number()) :: {:ok, __MODULE__.t()} | {:error, any()}
  def update(scene, time) do
    with {:ok, videos} <- update_videos(scene.videos, time),
         {:ok, {scene, transformations}} <-
           Transformation.update_all(scene, scene.transformations, time) do
      %__MODULE__{scene | videos: videos, transformations: transformations}
    else
      {:error, error} -> {:error, error}
    end
  end
end
