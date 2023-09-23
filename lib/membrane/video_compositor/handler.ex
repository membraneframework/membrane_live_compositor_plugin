defmodule Membrane.VideoCompositor.Handler do
  @moduledoc false

  alias Membrane.VideoCompositor

  @typedoc """
  Module implementing `#{__MODULE__}` behaviour.
  """
  @type t :: module()

  @type handler_state :: any()

  def handle_pads_change(
        inputs :: list(VideoCompositor.input_id()),
        outputs :: list(VideoCompositor.output_id()),
        state :: handler_state()
      ) ::
        {:update_scene, nodes :: list(map()), handler_state()} | handler_state()
end
