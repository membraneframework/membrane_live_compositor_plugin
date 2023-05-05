defmodule Membrane.VideoCompositor.Handler.CallbackContext.VideoAdd do
  @moduledoc """
  Structure representing a context that is passed to the
  `c:Membrane.VideoCompositor.Handler.handle_video_add/3` callback
  when a new Input Video is added.
  """

  use Membrane.VideoCompositor.Handler.CallbackContext
end
