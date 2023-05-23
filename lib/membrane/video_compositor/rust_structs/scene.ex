defmodule Membrane.VideoCompositor.RustStructs.Scene do
  @moduledoc """
  Rustler Friendly version on Scene.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @enforce_keys [:videos_configs]
  defstruct @enforce_keys

  @type video_id :: non_neg_integer()

  @type t :: %__MODULE__{
          videos_configs: %{video_id() => VideoConfig.t()}
        }

  @spec from_vc_scene(Membrane.VideoCompositor.Scene.t(), %{Pad.ref_t() => video_id()}) ::
          Membrane.VideoCompositor.RustStructs.Scene.t()
  def from_vc_scene(%Scene{videos_configs: videos_configs}, pads_to_ids) do
    videos_configs
    |> Map.new(fn {pad, video_config} -> {Map.get(pads_to_ids, pad), video_config} end)
    |> then(fn videos_configs ->
      %__MODULE__{videos_configs: videos_configs}
    end)
  end
end
