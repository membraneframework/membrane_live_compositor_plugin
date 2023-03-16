defmodule Membrane.VideoCompositor.Scene.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.VideoCompositor.Scene.Object.{InputVideo, Layout, Texture}

  defmodule RustlerFriendly do
    @moduledoc false

    alias Membrane.VideoCompositor.Scene.Object.InputVideo.RustlerFriendly, as: RFInputVideo
    alias Membrane.VideoCompositor.Scene.Object.Layout.RustlerFriendly, as: RFLayout
    alias Membrane.VideoCompositor.Scene.Object.Texture.RustlerFriendly, as: RFTexture

    @type name :: Membrane.VideoCompositor.Scene.Object.name()

    @type t :: {:layout, RFLayout.t()} | {:texture, RFTexture.t()} | {:video, RFInputVideo.t()}

    @type object_output_resolution :: Texture.output_resolution() | Layout.output_resolution()
  end

  @typedoc """
  Objects are renderable entities in VC, that can serve as input for other
  objects or as an output of the video.

  They are either Texture structs, structs defining Layouts
  following Layout.t() definition or InputVideo structs.
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

  Define how the output resolution of an object can be specified.
  Additionally, in Textures resolution can be specified as
  transformed resolution of the object input
  (e.g. for corners rounding - same as input,
  for cropping - accordingly smaller than input)
  """
  # FIXME: This and Texture.output_resolution should be reworked in some way.
  #        I don't know what these should look like on the rust side.
  @type object_output_resolution :: Texture.output_resolution() | Layout.output_resolution()

  @spec encode(t()) :: RustlerFriendly.t()
  def encode(object) do
    case object do
      %InputVideo{} -> {:video, InputVideo.encode(object)}
      %Texture{} -> {:texture, Texture.encode(object)}
      layout -> {:layout, Layout.encode(layout)}
    end
  end
end
