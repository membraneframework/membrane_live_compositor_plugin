defmodule Membrane.VideoCompositor.Scene.Layout do
        @moduledoc """
        Wraps specified implemented layout with input sources and output frame resolution.
        """

        alias Membrane.Pad
        alias Membrane.VideoCompositor.Scene.{Object, Resolution}

        @enforce_keys [:inputs_map, :layout, :resolution]
        defstruct @enforce_keys

        @typedoc """
        Wraps layout (like Grid, Overlay etc.) with mapping of input objects
        (which rendered output frames will be passed as inputs into layout).
        Specifies resolution of layout output frame - if object name is passed
        as resolution, it'll use resolution of object's output frame.
        """
        @type t :: %__MODULE__{
                inputs_map: %{Object.name_t() => any()},
                layout: LayoutSpec.definition_t(),
                resolution: Resolution.t() | Object.name_t()
              }
      end
