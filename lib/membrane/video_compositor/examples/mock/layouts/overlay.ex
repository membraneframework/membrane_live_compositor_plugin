defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Overlay do
  @moduledoc false

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.Position
  alias Membrane.VideoCompositor.Scene.Object

  @enforce_keys [:input_map]
  defstruct @enforce_keys

  @typedoc """
  Overlays textures received received from input pad or rendered from previous
  transformation / layouts
  """
  @type t :: %__MODULE__{
          input_map: %{Object.name_t() => Position.t()}
        }
end
