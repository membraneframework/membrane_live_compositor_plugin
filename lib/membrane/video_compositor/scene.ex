defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Scene describes positions and transformations of the videos, provided to the video compositor.
  """

  # alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager
  alias Membrane.VideoCompositor.Scene.{Element, ElementDescription, Video}

  @type error_t :: any()
  @type id_t :: non_neg_integer()
  @type component_t :: module()
  @type components_t :: keyword(component_t())

  @typedoc """
  Description of the scene.
  """
  @type scene_description_t() :: [
          videos: %{required(id_t()) => ElementDescription.t()},
          scenes: %{required(atom()) => t()},
          size: %{width: non_neg_integer(), height: non_neg_integer()}
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
          {t(), Manager.t()}
  def init(scene_description, manager) do
    videos = Keyword.get(scene_description, :videos, %{})
    scenes = Keyword.get(scene_description, :scenes, %{})
    scene_description = Keyword.drop(scene_description, [:videos, :scenes])

    scene = %__MODULE__{}

    unless Keyword.has_key?(scene_description, :size) do
      raise ArgumentError,
        message:
          "Scene spec has to contain `size: {width :: integer, height :: integer}` attribute."
    end

    {scene, manager} = add_videos(scene, manager, videos)

    {scene, manager} = add_scenes(scene, manager, scenes)

    element_description = ElementDescription.init(scene_description)

    {manager, state} = Manager.register_element(manager, element_description)

    components = ElementDescription.get_components(element_description)

    scene = %__MODULE__{scene | state: state, components: components}

    {scene, manager}
  end

  defp add_videos(scene, manager, videos) do
    Enum.reduce(videos, {scene, manager}, fn {video_id, video_description}, {scene, manager} ->
      element_description = ElementDescription.init(video_description)

      {manager, state} = Manager.register_element(manager, element_description)
      components = ElementDescription.get_components(element_description)
      scene = add_video(scene, video_id, components, state)
      {scene, manager}
    end)
  end

  defp add_scenes(scene, manager, scenes) do
    Enum.reduce(
      scenes,
      {scene, manager},
      fn {id, scene_description}, {scene, manager} ->
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

  @spec video_registered?(t(), id_t()) :: boolean()
  def video_registered?(scene, id) do
    Map.has_key?(scene.videos, id)
  end

  @spec video_position(t(), id_t()) :: Position.t()
  def video_position(scene, id) do
    Map.get(scene.videos, id).state |> Map.get(:position)
  end

  @spec add_scene(t(), id :: atom(), scene_description_t(), Manager.t()) ::
          {t(), Manager.t()}
  def add_scene(scene, scene_id, scene_description, manager) do
    {sub_scene, manager} = init(scene_description, manager)
    scene = %__MODULE__{scene | scenes: Map.put(scene.scenes, scene_id, sub_scene)}
    {scene, manager}
  end

  defp update_videos(videos, manager, context) do
    Enum.reduce(
      videos,
      videos,
      fn {id, video}, videos ->
        video = Video.update(video, manager, context)
        Map.put(videos, id, video)
      end
    )
  end

  defp update_sub_scenes(scenes, manager, context) do
    Enum.reduce(
      scenes,
      scenes,
      fn {id, scene}, scenes ->
        scene = update(scene, manager, context)
        Map.put(scenes, id, scene)
      end
    )
  end

  defp handle_update(scene, manager, context) do
    {state, components} = Manager.update(scene.state, scene.components, manager, context)
    %__MODULE__{scene | state: state, components: components}
  end

  @spec update(t, Manager.t(), context :: any) :: t
  def update(scene, manager, context) do
    videos = update_videos(scene.videos, manager, context)
    scenes = update_sub_scenes(scene.scenes, manager, context)
    scene = handle_update(scene, manager, context)

    %__MODULE__{
      scene
      | videos: videos,
        scenes: scenes
    }
  end
end
