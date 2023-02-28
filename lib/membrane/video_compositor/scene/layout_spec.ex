defmodule Membrane.VideoCompositor.Scene.LayoutSpec do
  @moduledoc """
  Layouts can take multiple renderable objects as an input and
  combine them into one frame. Fadings, Grids, Overlays, Transitions
  etc. can be defined as Layouts.
  """

  @typedoc """
  Layouts are represented my modules or module structs.
  """
  @type definition_t :: struct() | module()
end
