defmodule Membrane.VideoCompositor.Scene.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.VideoCompositor.Scene.Object.{InputVideo, Layout, Texture}

  @typedoc """
  Objects are renderable entities in VC, that can serve as input for other
  objects or as an output of the video.

  They are either Texture structs or structs defining Layouts
  following Layout.t() definition.
  """
  @type t :: Layout.t() | Texture.t() | InputVideo.t()

  @typedoc """
  Defines how an object can be referenced in Scene.

  Objects can be assigned to names and identified
  at other objects as inputs based on assigned names
  """
  @type name :: tuple() | atom()

  @typedoc """
  Defines how the input of an object can be specified
  in Video Compositor.
  """
  @type input :: name()

  @typedoc """
  Defines how the output resolution of an object can be specified.

  Additionally, in Textures resolution can be specified as
  transformed resolution of the object input
  (e.g. for corners rounding - same as input,
  for cropping - accordingly smaller than input)
  """
  @type object_output_resolution :: Texture.output_resolution() | Layout.output_resolution()
end
