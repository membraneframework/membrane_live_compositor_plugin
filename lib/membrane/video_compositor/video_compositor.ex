defmodule Membrane.VideoCompositor do
  @moduledoc """
  A bin responsible for doing framerate conversion on all input videos and piping them into the compositor element.
  """

  use Membrane.Bin
  alias Membrane.FramerateConverter
  alias Membrane.Pad
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.CompositorElement
  alias Membrane.VideoCompositor.RustStructs.VideoPlacement
  alias Membrane.VideoCompositor.VideoTransformations

  @typedoc """
  A message describing a compositor video placement update
  """
  @type update_placement_t ::
          {:update_placement, [{Membrane.Pad.ref_t(), VideoPlacement.t()}]}

  @typedoc """
  A message describing a compositor video transformations update
  """
  @type update_transformations_t ::
          {:update_transformations, [{Membrane.Pad.ref_t(), VideoTransformations.t()}]}

  def_options caps: [
                spec: RawVideo.t(),
                description: "Caps for the output video of the compositor"
              ],
              real_time: [
                spec: boolean(),
                description: "Set compositor into real_time mode",
                default: false
              ]

  def_input_pad :input,
    caps: {RawVideo, pixel_format: :I420},
    demand_unit: :buffers,
    availability: :on_request,
    options: [
      initial_placement: [
        spec: VideoPlacement.t(),
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
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    caps: {RawVideo, pixel_format: :I420},
    availability: :always

  @impl true
  def handle_init(options) do
    children = %{
      compositor: %CompositorElement{caps: options.caps, real_time: options.real_time}
    }

    links = [
      link(:compositor) |> to_bin_output(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    state = %{
      output_caps: options.caps
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:input, pad_id), context, state) do
    converter = {:framerate_converter, make_ref()}

    children = %{
      converter => %FramerateConverter{framerate: state.output_caps.framerate}
    }

    links = [
      link_bin_input(Pad.ref(:input, pad_id))
      |> to(converter)
      |> via_in(Pad.ref(:input, pad_id),
        options: [
          initial_placement: context.options.initial_placement,
          timestamp_offset: context.options.timestamp_offset,
          initial_video_transformations: context.options.initial_video_transformations
        ]
      )
      |> to(:compositor)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_other({:update_placement, placements}, _ctx, state) do
    {{:ok, forward: {:compositor, {:update_placement, placements}}}, state}
  end

  @impl true
  def handle_other({:update_transformations, transformations}, _ctx, state) do
    {{:ok, forward: {:compositor, {:update_transformations, transformations}}}, state}
  end
end
