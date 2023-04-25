defmodule Membrane.VideoCompositor.Handler.CallbackCtx.Info do
  @moduledoc """
  Structure representing a context that is passed when video compositor
  receives a message that is not recognized as an internal membrane message.
  """

  use Membrane.VideoCompositor.Handler.CallbackCtx,
    earliest_start: Membrane.Time.t()
end
