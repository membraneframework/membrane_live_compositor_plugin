defmodule Membrane.VideoCompositor.Handler.CallbackContext.VideoRemove do
  @moduledoc """
  Structure representing a context that is passed to the
  `c:Membrane.VideoCompositor.Handler.handle_video_remove/3` callback
  when an Input Video is removed.
  """

  use Membrane.VideoCompositor.Handler.CallbackContext
end
