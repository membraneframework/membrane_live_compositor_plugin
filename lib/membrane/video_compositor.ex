defmodule Membrane.VideoCompositor do
  @moduledoc """
  A bin responsible for doing framerate conversion on all input videos and piping them into the compositor element.
  """

  use Membrane.Bin
  alias Membrane.FramerateConverter
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.CompositorElement
  alias Membrane.VideoCompositor.RustStructs.VideoLayout

  @typedoc """
  A message describing a compositor layout update
  """
  @type update_layout_t :: {:update_layout, [{CompositorElement.name_t(), VideoLayout.t()}]}

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
      initial_layout: [
        spec: VideoLayout.t(),
        description: "Initial layout of the video on the screen"
      ],
      name: [
        spec: CompositorElement.name_t(),
        description: "A unique identifier for the video coming through this pad",
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
  def handle_pad_added(pad, context, state) do
    converter = {:framerate_converter, make_ref()}

    children = %{
      converter => %FramerateConverter{framerate: state.output_caps.framerate}
    }

    links = [
      link_bin_input(pad)
      |> to(converter)
      |> via_in(:input,
        options: [initial_layout: context.options.initial_layout, name: context.options.name]
      )
      |> to(:compositor)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_other({:update_layout, layouts}, _ctx, state) do
    {{:ok, forward: {:compositor, {:update_layout, layouts}}}, state}
  end
end
