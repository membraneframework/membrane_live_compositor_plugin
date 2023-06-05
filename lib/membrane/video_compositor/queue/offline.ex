defmodule Membrane.VideoCompositor.Queue.Offline do
  @moduledoc """
  A bin responsible for queueing frames with offline queueing strategy.
  """

  use Membrane.Bin
  alias Membrane.{FramerateConverter, RawVideo}
  alias Membrane.VideoCompositor.{CompositorCoreFormat, Scene}
  alias Membrane.VideoCompositor.Queue.Offline.Element, as: OfflineQueueElement
  alias Membrane.VideoCompositor.Scene.VideoConfig

  def_options output_framerate: [
                spec: RawVideo.framerate_t(),
                description: "Framerate of the output video of the compositor"
              ]

  def_input_pad :input,
    accepted_format: %RawVideo{pixel_format: :I420},
    availability: :on_request,
    options: [
      video_config: [
        spec: VideoConfig.t(),
        description: "Specify how single input video should be transformed"
      ],
      timestamp_offset: [
        spec: Membrane.Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ]
    ]

  def_output_pad :output,
    accepted_format: %CompositorCoreFormat{},
    availability: :always

  @impl true
  def handle_init(_ctx, %{output_framerate: output_framerate}) do
    spec =
      child(:queue_element, %OfflineQueueElement{output_framerate: output_framerate})
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
          timestamp_offset: context.options.timestamp_offset,
          video_config: context.options.video_config,
          vc_input_ref: Pad.ref(:input, pad_id)
        ]
      )
      |> get_child(:queue_element)

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(:input, pad_id), _context, state),
    do: {[remove_child: {:framerate_converter, pad_id}], state}

  @impl true
  def handle_parent_notification({:update_scene, scene = %Scene{}}, _context, state) do
    {[notify_child: {:queue_element, {:update_scene, scene}}], state}
  end
end
