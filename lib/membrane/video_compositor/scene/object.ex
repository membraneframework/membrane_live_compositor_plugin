defmodule Membrane.VideoCompositor.Scene.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene.{Layout, Object, Resolution, Texture}

  @typedoc """
  Objects are renderable entities in VC, that can serve as an input for other
  objects or as an output of the video
  """
  @type t :: Layout.definition_t() | Texture.t()

  @typedoc """
  Defines how object can be referenced in Scene.
  Objects can be assigned to names and identified
  at other objects as inputs based on assigned names
  """
  @type name_t :: tuple() | atom()

  @typedoc """
  Defines how input of an object can be specified
  in Video Compositor.
  """
  @type input_t :: name_t() | Pad.name_t()

  @typedoc """
  Define how output resolution of object can be specified.
  Additionally, in Textures resolution can be specified as
  transformed resolution of object input
  (e.g. for corners rounding - same as input,
  for cropping - accordingly smaller then input)
  """
  @type object_output_resolution_t :: Resolution.t() | Object.name_t()
end
