defmodule Membrane.VideoCompositor.Scene.Layout do
  @moduledoc """
  Structure representing Layout objects.

  Layouts can take multiple renderable objects as input and
  combine them into one frame. Fadings, Grids, Overlays, Transitions,
  etc. can be defined as Layouts.

  Basically multi-input, single-output node in processing graph.
  """
  alias Membrane.VideoCompositor.Scene.Object

  @typedoc """
  Keys enforced in Layout objects.
  """
  @type enforced_keys_t :: :inputs | :resolution

  @typedoc """
  Specify :inputs types in Layout structs.
  any() can be replaced with more specific
  type, such as atom()
  """
  @type inputs_t :: %{any() => Object.name_t()}

  @typedoc """
  Specify :resolution types in Layout structs.
  """
  @type resolution_t :: Object.object_output_resolution_t()

  @typedoc """
  Specify that Layouts:
    - should be defined as structs
    - should have :inputs and :resolution fields
    - can have custom fields
  """
  @type t :: %{
          :__struct__ => module(),
          :inputs => inputs_t(),
          :resolution => resolution_t(),
          optional(any()) => any()
        }

  @layout_enforce_keys [:inputs, :resolution]

  @doc """
  Returns all required fields in Layout structs.
  """
  @spec get_layout_enforce_keys() :: list(enforced_keys_t())
  def get_layout_enforce_keys() do
    @layout_enforce_keys
  end
end
