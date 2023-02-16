defmodule Membrane.VideoCompositor.Texture.Transformation do
  @moduledoc """
  Behaviour representing alternations of a Texture object.
  Under the hood transformations most likely are implemented as a fragment shaders.

  Render callback is a placeholder.
  """

  @type definition_t :: struct() | module()
  @type name_t :: tuple() | atom()

  @callback render() :: any()
end
