defmodule Membrane.VideoCompositor.Handler do
  @moduledoc false

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Scene

  @typedoc """
  Module implementing `#{__MODULE__}` behaviour.
  """
  @type t :: module()

  @type handler_state :: any()

  @callback handle_pads_change(
              inputs :: list(VideoCompositor.input_id()),
              outputs :: list(VideoCompositor.output_id()),
              state :: handler_state()
            ) ::
              {:update_scene, Scene.t(), handler_state()} | handler_state()
end
