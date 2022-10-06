defmodule Membrane.VideoCompositor.Scene.Element do
  @moduledoc """
  Set of universal elements types.
  """
  @type error_t :: any()
  @type component_t :: module()
  @type components_t :: keyword(component_t())
end
