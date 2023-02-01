defmodule Membrane.VideoCompositor.Compound.Layout do
  @moduledoc """
  Behaviour representing layous - modification combing multiple objects into one.

  Render callback is a placeholder.
  """

  @type definition_t :: struct() | module()
  @type name_t :: any()
  @type input_t :: any()

  @callback render() :: any()
end
