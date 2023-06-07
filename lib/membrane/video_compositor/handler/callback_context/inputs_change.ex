defmodule Membrane.VideoCompositor.Handler.CallbackContext.InputsChange do
  @moduledoc """
  Structure representing a context that is passed to the
  `c:Membrane.VideoCompositor.Handler.handle_inputs_change/1` callback
  when Video Compositor `Membrane.VideoCompositor.Handler.InputsDescription` change.
  """

  alias Membrane.Time
  alias Membrane.VideoCompositor.Handler.InputsDescription
  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:current_scene, :previous_inputs_description, :next_buffer_pts]
  defstruct @enforce_keys

  @typedoc """
  current_scene - scene used before callback invocation
  previous_inputs_description - inputs description (see `#{inspect(InputsDescription)}`) before input video change
  next_buffer_pts - presentation timestamp of first buffer composed with scene returned from callback
  """
  @type t :: %__MODULE__{
          current_scene: Scene.t(),
          previous_inputs_description: InputsDescription.t(),
          next_buffer_pts: Time.non_neg_t()
        }
end
