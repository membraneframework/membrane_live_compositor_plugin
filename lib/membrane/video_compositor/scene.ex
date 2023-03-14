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

  @spec encode(t()) :: Membrane.VideoCompositor.Scene.RustlerFriendly.Scene.t()
  def encode(scene) do
    alias Membrane.VideoCompositor.Scene.RustlerFriendly.Scene

    # convert pad refs form sources into Video structs

    encoded_objects =
      scene.objects
      |> Enum.map(fn {name, obj} -> {name, Object.encode(obj)} end)

    %Scene{
      objects: encoded_objects,
      output: scene.output
    }
  end
end
