defmodule Membrane.VideoCompositor.Queue do
  @moduledoc """
  Define input pads and compositor core contracts, that each
  implementation of queuing should meet.
  """

  alias Membrane.Buffer
  alias Membrane.Pad
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Scene

  @type stream_format_action :: {:stream_format, {Pad.ref_t(), CompositorCoreFormat.t()}}

  @type notify_compositor_scene :: [notify_child: {:output, {:update_scene, Scene.t()}}]

  @type buffer :: %Buffer{payload: %{Pad.ref_t() => frame_data :: binary()}}

  @type buffer_action :: {:buffer, {Pad.ref_t(), buffer()}}

  @type compositor_actions :: [
          stream_format_action()
          | notify_compositor_scene()
          | buffer_action()
        ]
end
