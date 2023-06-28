defmodule Membrane.VideoCompositor.Queue.Strategy do
  @moduledoc false

  # Defines input pads and compositor core contracts, that each
  # implementation of a queue should meet.

  alias Membrane.{Buffer, Pad}
  alias Membrane.VideoCompositor.{CompositorCoreFormat, SceneChangeEvent}

  @typedoc """
  Defines stream format action send to VC Core by Queue.
  """
  @type stream_format_action :: {:stream_format, {:output, CompositorCoreFormat.t()}}

  @typedoc """
  Defines scene update event action send to VC Core by Queue.
  """
  @type compositor_scene_event_action :: {:event, {:output, SceneChangeEvent.t()}}

  @typedoc """
  Defines frames buffer send to VC Core by Queue.
  """
  @type buffer :: %Buffer{payload: %{Pad.ref_t() => frame_data :: binary()}}

  @typedoc """
  Defines buffer action send to VC Core by Queue.
  """
  @type buffer_action :: {:buffer, {:output, buffer()}}

  @typedoc """
  Defines actions send to VC Core by Queue.
  Action should be send in this order:
  1. Stream format action
  2. Scene action
  3. Buffer action
  """
  @type compositor_actions :: [
          stream_format_action()
          | compositor_scene_event_action()
          | buffer_action()
        ]
end
