defmodule Membrane.VideoCompositor.Compound do
  @moduledoc """
  Structure representing Compound objects.

  Compound objects can be used to combine multiple inputs
  into one object, by applying `Membrane.VideoCompositor.Compound.Layout`
  to them, according to the `inputs_map` field.
  """

  alias Membrane.VideoCompositor.Object
  alias __MODULE__.{BaseSize, Layout}

  @enforce_keys [:base_size, :inputs_map, :layout]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          # base_size: BaseSize.t() | Object.input_t(),
          base_size: BaseSize.t(),
          inputs_map: %{Object.name_t() => Layout.input_t()},
          layout: Layout.name_t()
        }
end
