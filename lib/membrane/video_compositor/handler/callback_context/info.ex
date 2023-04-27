defmodule Membrane.VideoCompositor.Handler.CallbackContext.Info do
  @moduledoc """
  Structure representing a context that is passed to the
  `c:Membrane.VideoCompositor.Handler.handle_info/3` callback when
  video compositor receives a message that is not recognized as
  an internal membrane message.
  """

  earliest_start_doc = """
  `:earliest_start` - minimal start timestamp of a new scene.
  """

  use Membrane.VideoCompositor.Handler.CallbackContext,
      [{earliest_start_doc, {:earliest_start, Membrane.Time.t()}}]
end
