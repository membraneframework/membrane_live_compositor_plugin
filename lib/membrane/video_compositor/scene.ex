defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.VideoConfig

  @enforce_keys [:video_configs]
  defstruct @enforce_keys

  @typedoc """
  Specify how output frame should look like.

  If input pad isn't specified in `video_configs` it won't be used in composition.
  """
  @type t :: %__MODULE__{
          video_configs: %{Pad.ref_t() => VideoConfig.t()}
        }

  @spec empty() :: t()
  def empty() do
    %Scene{video_configs: %{}}
  end

  @spec pads(t()) :: MapSet.t()
  def pads(%__MODULE__{video_configs: video_configs}) do
    video_configs
    |> MapSet.new(fn {pad, _video_config} -> pad end)
  end

  @spec validate(t(), MapSet.t()) :: :ok
  def validate(scene = %__MODULE__{video_configs: video_configs}, input_pads) do
    scene_pads = Scene.pads(scene)

    unless MapSet.subset?(scene_pads, input_pads) do
      raise """
      The scene must include references only to VideoCompositor input pads.
      Scene: #{inspect(scene)}
      Scene pads: #{inspect(MapSet.to_list(scene_pads))}
      Input pads: #{inspect(MapSet.to_list(input_pads))}
      """
    end

    _checked_video_configs =
      video_configs
      |> Map.to_list()
      |> Enum.map(fn {pad, video_config} ->
        case video_config do
          %VideoConfig{} ->
            :ok

          _else ->
            raise """
            The scene must include only #{inspect(VideoConfig)} structs.
            Scene: #{inspect(scene)}
            Video config for pad: #{inspect(pad)} has improper config: #{inspect(video_config)}
            """
        end
      end)

    :ok
  end
end
