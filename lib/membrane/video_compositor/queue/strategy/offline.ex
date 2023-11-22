defmodule Membrane.VideoCompositor.Queue.Strategy.Offline do
  @moduledoc false
  # A bin responsible for queueing frames with offline queueing strategy.

  use Membrane.Bin
  alias Membrane.VideoCompositor
  alias Membrane.{FramerateConverter, RawVideo}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue.Strategy.Offline.Element, as: OfflineQueueElement

  def_options vc_init_options: [
                spec: VideoCompositor.init_options()
              ]

  def_input_pad :input,
    accepted_format: %RawVideo{pixel_format: :I420},
    availability: :on_request,
    options: [
      timestamp_offset: [
        spec: Membrane.Time.non_neg(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      metadata: [
        spec: VideoCompositor.input_pad_metadata(),
        default: nil
      ]
    ]

  def_output_pad :output,
    accepted_format: %CompositorCoreFormat{},
    availability: :always

  @impl true
  def handle_init(_ctx, %__MODULE__{vc_init_options: options}) do
    output_framerate = options.output_stream_format.framerate

    spec =
      child(:queue_element, %OfflineQueueElement{vc_init_options: options})
      |> bin_output()

    state = %{output_framerate: output_framerate}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:input, pad_id), context, state = %{output_framerate: framerate}) do
    spec =
      bin_input(Pad.ref(:input, pad_id))
      |> child({:framerate_converter, pad_id}, %FramerateConverter{
        framerate: framerate
      })
      |> via_in(Pad.ref(:input, pad_id),
        options: [
          timestamp_offset: context.pad_options.timestamp_offset,
          vc_input_ref: Pad.ref(:input, pad_id),
          metadata: context.pad_options.metadata
        ]
      )
      |> get_child(:queue_element)

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(:input, pad_id), _context, state),
    do: {[remove_children: {:framerate_converter, pad_id}], state}

  @impl true
  def handle_parent_notification(msg, _context, state) do
    {[notify_child: {:queue_element, msg}], state}
  end
end
