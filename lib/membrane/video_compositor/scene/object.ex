defmodule Membrane.VideoCompositor.Scene.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Scene.{Layout, Texture}

  @typedoc """
  An Object is a renderable entity within Video Compositor.
  """
  @type t :: Layout.definition_t() | Texture.t()

  @type name_t :: tuple() | atom()
  @type input_t :: t() | Pad.name_t()
end
