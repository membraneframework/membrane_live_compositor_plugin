defmodule Membrane.VideoCompositor do
  @moduledoc """
  A bin responsible for doing framerate conversion on all input videos and piping them into the compositor element.
  """

  use Membrane.Bin
  alias Membrane.{Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.Core, as: VCCore
  alias Membrane.VideoCompositor.{Queue, Scene, VideoConfig}

  @typedoc """
  Defines how VC should be notified with new scene -
  new composition schema.
  """
  @type scene_update_notification :: {:update_scene, Scene.t()}

  @typedoc """
  Defines implemented VC queuing strategies.
  Any queuing strategy should follow contracts defined in `#{inspect(Queue)}` module.
  """
  @type queuing_strategy :: :offline

  @init_metadata_doc """
  User-specified init metadata passed to handler callbacks.
  Passing init metadata into `c:Membrane.VideoCompositor.Handler.handle_init/1` callback allows
  the user to alternate custom-implemented init callback logic.
  """

  @typedoc @init_metadata_doc
  @type init_metadata :: any()

  @type init_options :: %__MODULE__{
          output_stream_format: RawVideo.t(),
          queuing_strategy: queuing_strategy(),
          metadata: init_metadata()
        }

  @input_pad_metadata_doc """
  User-specified input stream metadata passed to handler callbacks.
  Passing pad metadata into `c:Membrane.VideoCompositor.Handler.handle_inputs_change/3`
  callback, allows the user to alternate custom-implemented callbacks logic,
  e.g. prioritizing input stream in the `#{inspect(Scene)}` structs returned from callback.
  """

  @typedoc @input_pad_metadata_doc
  @type input_pad_metadata :: any()

  def_options output_stream_format: [
                spec: Membrane.RawVideo.t(),
                description: "Stream format for the output video of the compositor"
              ],
              queuing_strategy: [
                spec: queuing_strategy(),
                description: "Specify used frames queueing strategy",
                default: :offline
              ],
              metadata: [
                spec: init_metadata(),
                description: @init_metadata_doc,
                default: nil
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
        spec: Time.non_neg(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      metadata: [
        spec: input_pad_metadata(),
        description: @input_pad_metadata_doc,
        default: nil
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
