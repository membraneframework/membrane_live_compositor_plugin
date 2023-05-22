defmodule Membrane.VideoCompositor.Queue do
  @moduledoc """
  Defines input pads and compositor core contracts, that each
  implementation of a queue should meet.
  """

  alias Membrane.Buffer
  alias Membrane.Pad
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Scene

  @type stream_format_action :: {:stream_format, {Pad.ref_t(), CompositorCoreFormat.t()}}

  @type compositor_scene_event_action :: {:event, {:output, Scene.t()}}

  @type buffer :: %Buffer{payload: %{Pad.ref_t() => frame_data :: binary()}}

  @type buffer_action :: {:buffer, {Pad.ref_t(), buffer()}}

  @type compositor_actions :: [
          stream_format_action()
          | compositor_scene_event_action()
          | buffer_action()
        ]
end
