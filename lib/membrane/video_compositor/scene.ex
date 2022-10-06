defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Scene describes positions and transformations of the videos, provided to the video compositor.
  """

  # alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager
  alias Membrane.VideoCompositor.Scene.Element
  alias Membrane.VideoCompositor.Scene.ElementDescription
  alias Membrane.VideoCompositor.Scene.Video

  @type error_t :: any()
  @type id_t :: non_neg_integer()
  @type component_t :: module()
  @type components_t :: keyword(component_t())

  @typedoc """
  Description of the scene.
  """
  @type scene_description_t() :: [
          videos: %{required(id_t()) => ElementDescription.t()},
          scenes: %{required(atom()) => t()}
        ]

  @typedoc """
  Internal state of the scene.
  """
  @type t :: %__MODULE__{
          videos: %{required(id_t()) => Video.t()},
          components: components_t(),
          scenes: %{required(atom()) => t()},
          state: %{}
        }
  defstruct videos: %{}, components: [], scenes: %{}, state: %{}

  @spec init(scene_description_t(), Manager.t()) ::
          {:ok, {t(), Manager.t()}} | {:error, error_t()}
  def init(scene_description, manager) do
    videos = Keyword.get(scene_description, :videos, %{})
    scenes = Keyword.get(scene_description, :scenes, %{})
    scene_description = Keyword.drop(scene_description, [:videos, :scenes])
    scene = %__MODULE__{}

    with {:ok, {scene, manager}} <- add_videos(scene, manager, videos),
         {:ok, {scene, manager}} <- add_scenes(scene, manager, scenes),
         element_description <- ElementDescription.init(scene_description),
         {:ok, {manager, state}} <- Manager.register_element(manager, element_description) do
      components = ElementDescription.get_components(element_description)
      scene = %__MODULE__{scene | state: state, components: components}

      {:ok, {scene, manager}}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp add_videos(scene, manager, videos) do
    Enum.reduce(videos, {:ok, {scene, manager}}, fn {video_id, video_description},
                                                    {:ok, {scene, manager}} ->
      element_description = ElementDescription.init(video_description)

      {:ok, {manager, state}} = Manager.register_element(manager, element_description)
      components = ElementDescription.get_components(element_description)
      {:ok, {add_video(scene, video_id, components, state), manager}}
    end)
  end

  defp add_scenes(scene, manager, scenes) do
    Enum.reduce(
      scenes,
      {:ok, {scene, manager}},
      fn {id, scene_description}, {:ok, {scene, manager}} ->
        add_scene(scene, id, scene_description, manager)
      end
    )
  end

  @spec add_video(t(), id_t(), Element.components_t(), Video.state_t()) :: t()
  def add_video(scene, video_id, components \\ [], state \\ %{}) do
    video = Video.init(components, state)

    %__MODULE__{
      scene
      | videos: Map.put(scene.videos, video_id, video)
    }
  end

  @spec add_scene(t(), id :: atom(), scene_description_t(), Manager.t()) ::
          {:ok, {t(), Manager.t()}} | {:error, error_t()}
  def add_scene(scene, scene_id, scene_description, manager) do
    case init(scene_description, manager) do
      {:ok, {sub_scene, manager}} ->
        scene = %__MODULE__{scene | scenes: Map.put(scene.scenes, scene_id, sub_scene)}
        {:ok, {scene, manager}}

      {:error, error} ->
        {:error, error}
    end
  end

  # defp update_videos(videos, time) do
  #   Enum.reduce_while(
  #     videos,
  #     {:ok, videos},
  #     fn {id, video}, {:ok, videos} ->
  #       case Video.update(video, time) do
  #         {:ok, video} -> {:cont, {:ok, Map.put(videos, id, video)}}
  #         {:error, error} -> {:halt, {:error, error}}
  #       end
  #     end
  #   )
  # end

  # defp update_sub_scenes(scenes, time) do
  #   Enum.reduce_while(
  #     scenes,
  #     {:ok, scenes},
  #     fn {id, scene}, {:ok, scenes} ->
  #       case update(scene, time) do
  #         {:ok, scene} -> {:cont, {:ok, Map.put(scenes, id, scene)}}
  #         {:error, error} -> {:halt, {:error, error}}
  #       end
  #     end
  #   )
  # end

  @spec update(__MODULE__.t(), number()) :: {:ok, __MODULE__.t()} | {:error, any()}
  def update(_scene, _time) do
    # with {:ok, videos} <- update_videos(scene.videos, time),
    #      {:ok, scenes} <- update_sub_scenes(scene.scenes, time),
    #      {:ok, {scene, transformations}} <-
    #        Transformation.update_all(scene, scene.transformations, time) do
    #   {:ok, %__MODULE__{scene | videos: videos, transformations: transformations, scenes: scenes}}
    # else
    #   {:error, error} -> {:error, error}
    # end
    {:error, "Not implemented"}
  end
end
