defmodule Membrane.VideoCompositor.Handler.CallbackContext.Init do
  @moduledoc """
  Structure representing a context that is passed to the
  `c:Membrane.VideoCompositor.Handler.handle_init/1` callback
  when Video Compositor is initialized.
  """

  alias Membrane.VideoCompositor

  @enforce_keys [:init_options]
  defstruct @enforce_keys

  @typedoc """
  init_options - Initialization options of `Membrane.VideoCompositor`
  """
  @type t :: %__MODULE__{
          init_options: VideoCompositor.init_options()
        }
end
