defmodule Membrane.VideoCompositor.Scene do
  @moduledoc """
  Structure representing a top level specification of what is Video Compositor
  supposed to render.
  """

  alias Membrane.VideoCompositor.Compound.Layout
  alias Membrane.VideoCompositor.Object
  alias Membrane.VideoCompositor.Object.SimpleAlternation

  @enforce_keys [:objects, :render]
  defstruct @enforce_keys ++ [alternations: [], layouts: []]

  @type t :: %__MODULE__{
          alternations: [{SimpleAlternation.name_t(), SimpleAlternation.definition_t()}],
          layouts: [{Layout.name_t(), Layout.definition_t()}],
          objects: [{Object.name_t(), Object.t()}],
          render: render_t()
        }

  @typedoc """
  Defines allowed type top level object, that is going to be rendered
  as an output of Video Compositor.
  """
  @type render_t :: Object.t()
end
