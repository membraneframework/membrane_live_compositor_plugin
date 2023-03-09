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
  @type enforced_keys :: :inputs | :resolution

  @typedoc """
  Specify :inputs types in Layout structs.
  any() can be replaced with more specific
  type, such as atom()
  """
  @type inputs :: %{any() => Object.name()}

  @typedoc """
  Specify :resolution types in Layout structs.
  """
  @type resolution :: Object.object_output_resolution()

  @typedoc """
  Specify that Layouts:
    - should be defined as structs
    - should have :inputs and :resolution fields
    - can have custom fields
  """
  @type t :: %{
          :__struct__ => module(),
          :inputs => inputs(),
          :resolution => resolution(),
          optional(any()) => any()
        }
end
