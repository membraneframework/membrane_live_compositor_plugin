defmodule Membrane.VideoCompositor.Compound do
  @moduledoc false

  alias Membrane.VideoCompositor.Object
  alias __MODULE__.{BaseSize, Layout}

  @enforce_keys [:base_size, :inputs_map, :layout]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          base_size: BaseSize.t() | Object.input_t(),
          inputs_map: %{Object.name_t() => Layout.input_t()},
          layout: Layout.name_t()
        }
end
