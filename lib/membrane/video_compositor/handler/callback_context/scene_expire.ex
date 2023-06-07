defmodule Membrane.VideoCompositor.Handler.CallbackContext.SceneExpire do
  @moduledoc """
  Structure representing a context that is passed to the
  `c:Membrane.VideoCompositor.Handler.handle_scene_expire/2` callback
  when a Temporal Scene expires.
  """

  use Membrane.VideoCompositor.Handler.CallbackContext
end
