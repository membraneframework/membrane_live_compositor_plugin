defmodule Membrane.VideoCompositor.SceneChangeEvent do
  @moduledoc false
  alias Membrane.VideoCompositor.Scene

  @derive [Membrane.EventProtocol]
  @enforce_keys [:new_scene]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          new_scene: Scene.t()
        }
end
