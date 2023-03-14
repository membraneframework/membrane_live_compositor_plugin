defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.

  """

  alias Membrane.VideoCompositor.Scene.Object

  @enforce_keys [:objects, :output]
  defstruct @enforce_keys

  @typedoc """
  The main part of the Scene are `Membrane.VideoCompositor.Scene.Object`s
  and interactions between them. There are three kinds of Objects:
  - `Membrane.VideoCompositor.Scene.Object.InputVideo` - which maps
  an input pad of element into Scene object.
  - `Membrane.VideoCompositor.Scene.Object.Texture` - single input object,
  taking frames and applying a series of transformations onto it.
  - `Membrane.VideoCompositor.Scene.Object.Layout` - combining
  frames from multiple inputs into a single output.
  """
  @type t :: %__MODULE__{
          objects: [{Object.name(), Object.t()}],
          output: Object.name()
        }
end
