defmodule Membrane.VideoCompositor do
  @moduledoc """
  A bin responsible for doing framerate conversion on all input videos and piping them into the compositor element.
  """

  use Membrane.Bin
  alias Membrane.{Pad, RawVideo}
  alias Membrane.VideoCompositor.Core, as: VCCore
  alias Membrane.VideoCompositor.{Queue, Scene}
  alias Membrane.VideoCompositor.VideoConfig

  @typedoc """
  Defines implemented VC queuing strategies.
  Any queuing strategy should follow contracts defined in `Membrane.VideoCompositor.Queue` module.
  """
  @type queuing_strategy :: :offline

  @typedoc """
  Defines how VC should be notified with new scene -
  new composition schema.
  """
  @type scene_update_notification :: {:update_scene, Scene.t()}

  @type init_options :: %__MODULE__{
          output_stream_format: RawVideo.t(),
          queuing_strategy: queuing_strategy()
        }

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
        options = %__MODULE__{output_stream_format: output_stream_format = %RawVideo{}}
      ) do
    spec =
      child(:queue, Queue.get_queue(options))
      |> child(:compositor_core, %VCCore{
        output_stream_format: output_stream_format
      })
      |> bin_output()

    {[spec: spec], %{}}
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
  def handle_parent_notification({:update_scene, scene = %Scene{}}, _ctx, state) do
    {[notify_child: {:queue, {:update_scene, scene}}], state}
  end
end
