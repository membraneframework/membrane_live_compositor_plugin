defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.VideoCompositor.Scene.Object

  @enforce_keys [:objects, :output]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          objects: [{Object.name(), Object.t()}],
          output: Object.name()
        }
end
