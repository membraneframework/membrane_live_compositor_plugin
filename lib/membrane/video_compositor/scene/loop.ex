defmodule Membrane.VideoCompositor.Scene.Loop do
  @moduledoc """
  TODO:
  """

  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:scene]
  defstruct @enforce_keys

  @typedoc """
  TODO:
  """
  @type t :: %__MODULE__{scene: Scene.temporal_t()}
end
