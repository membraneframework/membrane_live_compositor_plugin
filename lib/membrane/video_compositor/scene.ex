defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.VideoCompositor.Object
  alias __MODULE__.{Expiring, Loop, Repeat}

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

  @typedoc """
  TODO:
  """
  @type temporal_t :: Expiring.t() | Loop.t() | Repeat.t()

  defmodule RustlerFriendly do
    @moduledoc false
    # A rustler-friendly version of the Scene, prepared for rust serialization
    alias Membrane.VideoCompositor.Object.RustlerFriendly, as: RFObject

    @type t :: %__MODULE__{
            objects: [{RFObject.name(), RFObject.t()}],
            output: RFObject.name()
          }

    @enforce_keys [:objects, :output]
    defstruct @enforce_keys
  end

  @doc false
  # Encode the scene to a Scene.RustlerFriendly in order to prepare it for
  # the rust conversion.
  @spec encode(t()) :: RustlerFriendly.t()
  def encode(scene) do
    encoded_objects =
      scene.objects
      |> Enum.map(fn {name, obj} -> {Object.encode_name(name), Object.encode(obj)} end)

    %RustlerFriendly{
      objects: encoded_objects,
      output: Object.encode_name(scene.output)
    }
  end
end
