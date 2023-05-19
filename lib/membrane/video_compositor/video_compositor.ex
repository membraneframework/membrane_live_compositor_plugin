defmodule Membrane.VideoCompositor do
  @moduledoc """
  A bin responsible for doing framerate conversion on all input videos and piping them into the compositor element.
  """

  use Membrane.Bin
  alias Membrane.{Pad, RawVideo}
  alias Membrane.VideoCompositor.Core, as: VC_Core
  alias Membrane.VideoCompositor.Queue.Offline, as: OfflineQueue
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @type queuing_strategy :: :offline

  def_options output_stream_format: [
                spec: Membrane.RawVideo.t(),
                description: "Stream format for the output video of the compositor"
              ],
              queuing_strategy: [
                spec: queuing_strategy(),
                description: "Specify used frames queueing strategy",
                default: :offline
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
    accepted_format: %RawVideo{pixel_format: :I420},
    availability: :always

  @impl true
  def handle_init(
        _ctx,
        options = %{output_stream_format: output_stream_format = %RawVideo{framerate: framerate}}
      ) do
    spec =
      child(:queue, get_queue(options))
      |> child(:compositor, %VC_Core{
        output_stream_format: output_stream_format
      })
      |> bin_output()

    state = %{output_framerate: framerate}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:input, pad_id), context, state) do
    spec =
      bin_input(Pad.ref(:input, pad_id))
      |> via_in(Pad.ref(:input, pad_id),
        options: [
          timestamp_offset: context.options.timestamp_offset,
          video_config: context.options.video_config
        ]
      )
      |> get_child(:queue)

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(:input, pad_id), _context, state),
    do: {[remove_child: {:queue, pad_id}], state}

  @impl true
  def handle_parent_notification({:update_scene, scene = %Scene{}}, _ctx, state) do
    {[notify_child: {:queue, {:update_scene, scene}}], state}
  end

  defp get_queue(options = %{queuing_strategy: :offline}) do
    %OfflineQueue{output_framerate: options.output_stream_format.framerate}
  end
end
