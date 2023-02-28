defmodule Membrane.VideoCompositor.Scene.Object do
  @moduledoc false
  alias Membrane.VideoCompositor.Scene.Layout
  alias Membrane.VideoCompositor.Scene.Texture

  @type name_t :: atom() | tuple()

  @type t :: Texture.t() | Layout.t()
end
