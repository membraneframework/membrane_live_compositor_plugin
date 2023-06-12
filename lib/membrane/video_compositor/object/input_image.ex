defmodule Membrane.VideoCompositor.Object.InputImage do
  @moduledoc """
  Structure representing `InputImage` wrapper for using single frame as
  an object in a scene.

  It's useful, when user want to use some single image
  for composing (e.g. some background). With this, user don't have to
  artificially turn image into video, to use it in composition.
  """

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Resolution

  @enforce_keys [:frame, :stream_format]
  defstruct @enforce_keys

  @typedoc """
  Defines wrapper for static VC frame InputStatic.

  The `frame` is a raw video binary.
  In `stream_format` only the `width`, `height`, and `pixel_format`
  fields are used, the rest is ignored (`framerate` and `aligned`
  don't have any meaning in the case of static image).
  Currently, only `:I420` `pixel_format` is supported.
  """
  @type t :: %__MODULE__{
          frame: binary(),
          stream_format: RawVideo.t()
        }

  defmodule RustlerFriendly do
    @moduledoc false

    @type t :: %__MODULE__{
            frame: binary(),
            resolution: Resolution.t()
          }

    @enforce_keys [:frame, :resolution]
    defstruct @enforce_keys
  end

  @spec encode(t()) :: RustlerFriendly.t()
  def encode(image) do
    %__MODULE__{
      frame: frame,
      stream_format: %RawVideo{
        width: width,
        height: height,
        pixel_format: :I420
      }
    } = image

    %RustlerFriendly{
      frame: frame,
      resolution: %Resolution{
        width: width,
        height: height
      }
    }
  end
end