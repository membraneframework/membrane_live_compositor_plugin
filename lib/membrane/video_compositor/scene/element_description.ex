defmodule Membrane.VideoCompositor.Scene.ElementDescription do
  @moduledoc """
  Parses user-given description of the element into initialization ready object.
  """
  alias Membrane.VideoCompositor.Scene.Element

  @type component_t :: module()
  @type options_t :: any() | nil

  @type entry_t :: struct() | {component_t(), options_t()} | component_t()
  @type entries_t :: keyword(entry_t())

  @type components_t :: keyword({component_t(), options_t})

  @type t :: %__MODULE__{
          state: any(),
          components: components_t()
        }
  defstruct state: nil, components: []

  @spec init(
          entries_t,
          state :: any(),
          (state :: any, id :: atom, property :: any -> state :: any)
        ) :: t
  def init(entries, state \\ %{}, inject \\ &Map.put/3) do
    {state, components} =
      Enum.reduce(entries, {state, []}, fn {id, entry}, {state, components} ->
        case entry do
          property when is_struct(property) or is_map(property) ->
            {inject.(state, id, property), components}

          {module, options} ->
            {state, Keyword.put(components, id, {module, options})}

          module when is_atom(module) ->
            {state, Keyword.put(components, id, {module, nil})}
        end
      end)

    %__MODULE__{state: state, components: Enum.reverse(components)}
  end

  @spec get_components(t()) :: Element.components_t()
  def get_components(description) do
    Keyword.new(description.components, fn {id, {module, _state}} -> {id, module} end)
  end
end
