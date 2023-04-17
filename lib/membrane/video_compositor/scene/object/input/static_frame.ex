defmodule Membrane.VideoCompositor.Scene.Object.Input.StaticFrame do
  @moduledoc """
  Structure representing `StaticFrame` wrapper for using single frame as
  an object in a scene. It's useful, when user want to use some single image
  for composing (e.g. some background). With this, user don't have to
  artificially turn image into video, to use it in composition.
  """

  alias Membrane.RawVideo

  @enforce_keys [:frame, :stream_format]
  defstruct @enforce_keys

  @typedoc """
  Defines wrapper for static VC frame InputStatic.
  The `frame` is raw video binary.
  In `stream_format` only the `width`, `height`, and `pixel_format`
  fields are used, the rest is ignored (`framerate` and `aligned`
  don't have any meaning in the case of static image).
  Currently, only `:I420` `pixel_format` is supported.
  """
  @type t :: %__MODULE__{
          frame: binary(),
          stream_format: RawVideo.t()
        }
end
