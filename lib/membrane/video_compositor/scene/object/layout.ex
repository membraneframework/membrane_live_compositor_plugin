defmodule Membrane.VideoCompositor.Scene.Object.Layout do
  @moduledoc """
  Structure representing Layout objects.

  Layouts can take multiple renderable objects as input and combine
  them into one frame. Fadings, Grids, Overlays, Transitions, etc.
  can be defined as Layouts.

  Basically it's a multi-input, single-output node in processing graph.
  """
  alias Membrane.VideoCompositor.Scene.{Object, Resolution}

  @typedoc """
  Type of a map defining on how to map internal layout's ids
  to Scene objects
  """
  @type inputs :: %{any() => Object.input()}

  @typedoc """
  Defines how the output resolution of a layout texture can be specified.

  Texture resolution can be specified as:
  - plain `Membrane.VideoCompositor.Resolution.t()`
  - resolution of another object
  """
  @type output_resolution :: Resolution.t() | Object.name()

  @typedoc """
  Specify that Layouts:
    - should be defined as structs
    - should have :inputs and :resolution fields
    - can have custom fields
  """
  @type t :: %{
          :__struct__ => module(),
          :inputs => inputs(),
          :resolution => output_resolution(),
          optional(any()) => any()
        }
end
