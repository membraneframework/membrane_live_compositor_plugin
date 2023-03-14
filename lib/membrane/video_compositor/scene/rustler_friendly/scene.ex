defmodule Membrane.VideoCompositor.Scene.RustlerFriendly.Scene do
  @moduledoc false
  alias Membrane.VideoCompositor.Scene.RustlerFriendly.Object

  @type t :: %__MODULE__{
          objects: [{Object.name(), Object.t()}],
          output: Object.name()
        }

  @enforce_keys [:objects, :output]
  defstruct @enforce_keys
end
