defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Grid do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene.{Layout, Object, Resolution}

  @enforce_keys [:videos_count] ++ Layout.get_layout_enforce_keys()
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          videos_count: non_neg_integer(),
          inputs: %{
            integer() => Object.name_t()
          },
          resolution: Resolution.t()
        }
end
