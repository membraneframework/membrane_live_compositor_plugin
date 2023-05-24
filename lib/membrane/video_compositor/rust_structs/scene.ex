defmodule Membrane.VideoCompositor.RustStructs.Scene do
  @moduledoc """
  Rustler Friendly version of `Membrane.VideoCompositor.Scene`.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @enforce_keys [:video_configs]
  defstruct @enforce_keys

  @type video_id :: non_neg_integer()

  @type t :: %__MODULE__{
          video_configs: %{video_id() => VideoConfig.t()}
        }

  @spec from_vc_scene(Membrane.VideoCompositor.Scene.t(), %{Pad.ref_t() => video_id()}) ::
          Membrane.VideoCompositor.RustStructs.Scene.t()
  def from_vc_scene(%Scene{video_configs: video_configs}, pads_to_ids) do
    video_configs
    |> Map.new(fn {pad, video_config} -> {Map.fetch!(pads_to_ids, pad), video_config} end)
    |> then(fn video_configs ->
      %__MODULE__{video_configs: video_configs}
    end)
  end
end
