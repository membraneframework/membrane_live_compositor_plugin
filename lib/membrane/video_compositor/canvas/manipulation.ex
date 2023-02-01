defmodule Membrane.VideoCompositor.Canvas.Manipulation do
  @moduledoc """
  Behaviour representing alternations of a Canvas object.
  Under the hood manipulations most likely are implemented as a vertex shaders.

  Render callback is a placeholder.
  """

  @type definition_t :: struct() | module()
  @type name_t :: any()

  @callback render() :: any()
end
