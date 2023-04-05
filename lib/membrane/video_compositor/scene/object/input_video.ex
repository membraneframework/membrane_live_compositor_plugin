defmodule Membrane.VideoCompositor.Scene.Object.InputVideo do
  @moduledoc """
  Structure representing `InputVideo` wrapper for using input
  Membrane Pad of an element as a object in a scene.
  """
  alias Membrane.Pad

  defmodule RustlerFriendly do
    @moduledoc false

    @type t :: %__MODULE__{
            input_pad: binary()
          }

    @enforce_keys [:input_pad]
    defstruct @enforce_keys
  end

  @enforce_keys [:input_pad]
  defstruct @enforce_keys

  @typedoc """
  Defines pad wrapper.
  """
  @type t :: %__MODULE__{
          input_pad: Pad.ref_t()
        }

  @spec encode(t()) :: RustlerFriendly.t()
  def encode(video) do
    %RustlerFriendly{
      input_pad: inspect(video.input_pad)
    }
  end
end
