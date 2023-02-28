defmodule Membrane.VideoCompositor.Scene.Object do
  @moduledoc """
  Renderable instance in Video Compositor.
  Each object can be an input for transformation or layout
  and at a low level will be rendered as simple texture before being
  processed in transformation / layout.
  """
  alias Membrane.VideoCompositor.Scene.{Layout, Texture}

  @typedoc """
  Defines what can be used as an object name
  """
  @type name_t :: atom() | tuple()

  @typedoc """
  Defines all renderable objects types in Video Compositor.
  """
  @type t :: Texture.t() | Layout.t()
end
