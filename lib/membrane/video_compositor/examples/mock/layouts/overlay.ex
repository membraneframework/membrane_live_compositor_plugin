defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Overlay do
  @moduledoc false

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.Position
  alias Membrane.VideoCompositor.Scene.{Layout, Object, Resolution}

  @enforce_keys [:overlay_spec] ++ Layout.get_layout_enforce_keys()
  defstruct @enforce_keys

  @typedoc """
  Name used to identify create placing name - position and relationship.
  """
  @type placing_name_t :: atom()

  @typedoc """
  Overlays textures received received from input pad or rendered from previous
  transformation / layouts
  """
  @type t :: %__MODULE__{
          overlay_spec: %{placing_name_t() => Position.t()},
          inputs: %{placing_name_t() => Object.name_t()},
          resolution: Resolution.t()
        }
end
