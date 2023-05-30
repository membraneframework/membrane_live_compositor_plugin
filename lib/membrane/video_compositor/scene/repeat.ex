defmodule Membrane.VideoCompositor.Scene.Repeat do
  @moduledoc """
  TODO:
  """

  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:count, :scene, :next]
  defstruct @enforce_keys

  @typedoc """
  TODO:
  """
  @type t :: %__MODULE__{
          count: integer(),
          scene: Scene.t(),
          next: Scene.t() | Scene.temporal_t()
        }
end
