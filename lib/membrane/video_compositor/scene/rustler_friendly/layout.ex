defmodule Membrane.VideoCompositor.Scene.RustlerFriendly.Layout do
  @moduledoc false
  alias Membrane.VideoCompositor.Scene.Resolution
  alias Membrane.VideoCompositor.Scene.RustlerFriendly.Object

  @type inputs :: %{any() => Object.name()}
  @type output_resolution :: {:resolution, Resolution.t()} | {:name, Object.name()}
  @type rust_representation :: reference()

  @type t :: %__MODULE__{
          :inputs => inputs(),
          :resolution => output_resolution(),
          # unsure about calling this `implementation`
          :implementation => rust_representation()
        }

  @enforce_keys [:inputs, :resolution, :implementation]
  defstruct @enforce_keys
end
