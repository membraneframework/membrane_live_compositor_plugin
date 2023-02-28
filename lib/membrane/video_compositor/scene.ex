defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what Video Compositor is
  supposed to render.
  """

  alias Membrane.VideoCompositor.Scene.Object

  @enforce_keys [:objects, :output]
  defstruct @enforce_keys

  @typedoc """
  Defines all modifications applied to frames incoming to Video Compositor
  via input pads and specify how output frame should look like.
  """
  @type t :: %__MODULE__{
          objects: [{Object.name_t(), Object.t()}],
          output: Object.name_t()
        }
end
