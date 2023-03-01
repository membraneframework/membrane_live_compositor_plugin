defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.VideoCompositor.Scene.Object

  @enforce_keys [:objects, :output]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          objects: [{Object.name_t(), Object.t()}],
          output: Object.name_t()
        }
end
