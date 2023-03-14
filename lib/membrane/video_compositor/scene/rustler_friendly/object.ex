defmodule Membrane.VideoCompositor.Scene.RustlerFriendly.Object do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene.RustlerFriendly.{InputVideo, Layout, Texture}

  @type name :: Membrane.VideoCompositor.Scene.Object.name()

  @type t :: {:layout, Layout.t()} | {:texture, Texture.t()} | {:video, InputVideo.t()}

  @type object_output_resolution :: Texture.output_resolution() | Layout.output_resolution()
end
