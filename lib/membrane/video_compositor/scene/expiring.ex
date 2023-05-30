defmodule Membrane.VideoCompositor.Scene.Expiring do
  @moduledoc """
  TODO:
  """

  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:duration, :scene, :next]
  defstruct @enforce_keys

  @typedoc """
  TODO:
  """
  @type t :: %__MODULE__{
          duration: Membrane.Time.t(),
          scene: Scene.t(),
          next: Scene.t() | Scene.temporal_t()
        }
end
