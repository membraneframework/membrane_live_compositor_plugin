defmodule Membrane.VideoCompositor.Scene.Object.InputVideo do
  @moduledoc """
  Structure representing `InputVideo` wrapper for using input
  Membrane Pad of an element as a object in a scene.
  """
  alias Membrane.Pad

  @enforce_keys [:input_pad]
  defstruct @enforce_keys

  @typedoc """
  Defines pad wrapper.
  """
  @type t :: %__MODULE__{
          input_pad: Pad.ref_t()
        }

  @spec encode(t()) :: Membrane.VideoCompositor.Scene.RustlerFriendly.InputVideo.t()
  def encode(video) do
    alias Membrane.VideoCompositor.Scene.RustlerFriendly.InputVideo

    %InputVideo{
      input_pad: video.input_pad
    }
  end
end
