defmodule Membrane.VideoCompositor.Scene.Layout do
  @moduledoc """
  Structure representing Layout objects.

  Layouts can take multiple renderable objects as an input and
  combine them into one frame. Fadings, Grids, Overlays, Transitions
  etc. can be defined as Layouts.
  """

  @type definition_t :: struct()

  @typedoc """
  Keys enforced in Layout objects
  """
  @type enforced_keys_t :: :inputs | :resolution

  @layout_enforce_keys [:inputs, :resolution]

  @spec get_layout_enforce_keys() :: list(enforced_keys_t())
  def get_layout_enforce_keys() do
    @layout_enforce_keys
  end
end
