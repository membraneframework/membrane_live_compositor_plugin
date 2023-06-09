defmodule Membrane.VideoCompositor do
  @moduledoc """
  A bin responsible for doing framerate conversion on all input videos and piping them into the compositor element.
  """

  use Membrane.Bin
  alias Membrane.FramerateConverter
  alias Membrane.Pad
  alias Membrane.VideoCompositor.CompositorElement
  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.VideoTransformations

  @typedoc """
  A message describing a compositor video placement update
  """
  @type update_placement ::
          {:update_placement, [{Membrane.Pad.ref_t(), BaseVideoPlacement.t()}]}

  @typedoc """
  A message describing a compositor video transformations update
  """
  @type update_transformations ::
          {:update_transformations, [{Membrane.Pad.ref_t(), VideoTransformations.t()}]}

  @init_metadata_doc """
  User-specified init metadata passed to handler callbacks.
  Passing init metadata into `c:Membrane.VideoCompositor.Handler.handle_init/1` callback allows
  the user to alternate custom-implemented init callback logic.
  """

  @typedoc @init_metadata_doc
  @type init_metadata :: any()

  @type init_options :: %{:stream_format => Membrane.RawVideo.t(), :metadata => init_metadata()}

  def_options stream_format: [
                spec: Membrane.RawVideo.t(),
                description: "Stream format for the output video of the compositor"
              ],
              metadata: [
                spec: init_metadata(),
                description: @init_metadata_doc,
                default: nil
              ]

  @input_pad_metadata_doc """
  User-specified input stream metadata passed to handler callbacks.
  Passing pad metadata into `c:Membrane.VideoCompositor.Handler.handle_inputs_change/3`
  callback, allows the user to alternate custom-implemented callbacks logic,
  e.g. prioritizing input stream in the `#{inspect(Scene)}` structs returned from callback.
  """

  @typedoc @input_pad_metadata_doc
  @type input_pad_metadata :: any()

  def_input_pad :input,
    accepted_format: %Membrane.RawVideo{pixel_format: :I420},
    availability: :on_request,
    options: [
      initial_placement: [
        spec: BaseVideoPlacement.t(),
        description: "Initial placement of the video on the screen"
      ],
      timestamp_offset: [
        spec: Membrane.Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      initial_video_transformations: [
        spec: VideoTransformations.t(),
        description:
          "Specify the initial types and the order of transformations applied to video.",
        # Can't set here struct, due to quote error (AST invalid node).
        # Calling Macro.escape() returns tuple and makes code more error prone and less readable.
        default: nil
      ],
      metadata: [
        spec: init_metadata(),
        description: @init_metadata_doc,
        default: nil
      ]
    ]

  def_output_pad :output,
    accepted_format: %Membrane.RawVideo{pixel_format: :I420},
    availability: :always

  @impl true
  def handle_init(_ctx, options) do
    spec =
      child(:compositor, %CompositorElement{
        stream_format: options.stream_format
      })
      |> bin_output()

    state = %{output_stream_format: options.stream_format}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(:input, pad_id), _context, state),
    do: {[remove_child: {:framerate_converter, pad_id}], state}

  @impl true
  def handle_pad_added(Pad.ref(:input, pad_id), context, state) do
    spec =
      bin_input(Pad.ref(:input, pad_id))
      |> child({:framerate_converter, pad_id}, %FramerateConverter{
        framerate: state.output_stream_format.framerate
      })
      |> via_in(Pad.ref(:input, pad_id),
        options: [
          initial_placement: context.options.initial_placement,
          timestamp_offset: context.options.timestamp_offset,
          initial_video_transformations: context.options.initial_video_transformations
        ]
      )
      |> get_child(:compositor)

    {[spec: spec], state}
  end

  @impl true
  def handle_parent_notification({:update_placement, placements}, _ctx, state) do
    {[notify_child: {:compositor, {:update_placement, placements}}], state}
  end

  @impl true
  def handle_parent_notification({:update_transformations, transformations}, _ctx, state) do
    {[notify_child: {:compositor, {:update_transformations, transformations}}], state}
  end
end
