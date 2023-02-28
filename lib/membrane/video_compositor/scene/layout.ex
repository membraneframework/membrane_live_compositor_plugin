defmodule Membrane.VideoCompositor.Scene.Layout do
  @moduledoc false

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene.LayoutSpec
  alias Membrane.VideoCompositor.Scene.Object
  alias Membrane.VideoCompositor.Scene.Resolution
  alias Membrane.VideoCompositor.Scene.TransformationSpec

  @type input_t :: Pad.name_t() | TransformationSpec.definition_t() | LayoutSpec.definition_t()
  @type resolution_t ::
          Pad.name_t() | TransformationSpec.definition_t() | LayoutSpec.definition_t()

  @enforce_keys [:inputs_map, :layout, :resolution]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs_map: %{Object.name_t() => any()},
          layout: LayoutSpec.definition_t(),
          resolution: Resolution.t()
        }
end
