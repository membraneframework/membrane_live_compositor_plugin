defmodule Membrane.VideoCompositor.CompositorElement do
  @moduledoc false
  # The element responsible for composing frames.

  #  Right now, the compositor only operates in offline mode, which means that it will wait for
  #  all videos to have a recent enough frame available, however long it might take, and then perform the compositing.

  use Membrane.Filter

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Object.Layout
  alias Membrane.VideoCompositor.Transformation
  alias Membrane.VideoCompositor.WgpuAdapter

  defmodule State do
    @moduledoc false
    # The internal state of the compositor
    @type t() :: %__MODULE__{
            native_state: WgpuAdapter.native_state()
          }

    @enforce_keys [:native_state]
    defstruct @enforce_keys
  end

  def_options transformations: [
                spec: list(Transformation.transformation_module()),
                description: """
                A list of modules that implement the `Membrane.VideoCompositor.Transformation` behaviour.
                These modules can later be used in the scene passed to this compositor.
                """,
                default: []
              ],
              layouts: [
                spec: list(Layout.layout_module()),
                description: """
                A list of modules that implement the `Membrane.VideoCompositor.Layout` behaviour.
                These modules can later be used in the scene passed to this compositor.
                """,
                default: []
              ]

  def_input_pad :input,
    availability: :on_request,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420},
    options: [
      timestamp_offset: [
        spec: Membrane.Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ]
    ]

  def_output_pad :output,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420}

  @impl true
  def handle_init(_ctx, options) do
    native_state = WgpuAdapter.init()

    :ok = WgpuAdapter.init_and_register_transformations(native_state, options.transformations)
    :ok = WgpuAdapter.init_and_register_layouts(native_state, options.layouts)

    state = %State{
      native_state: native_state
    }

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state = %State{}) do
    {[], state}
  end

  @impl true
  def handle_pad_added(_pad, _context, state = %State{}) do
    {[], state}
  end

  @impl true
  def handle_stream_format(_pad, _stream_format, _context, state = %State{}) do
    {[], state}
  end

  @impl true
  def handle_process(_pad, _buffer, _context, state = %State{}) do
    {[], state}
  end

  @impl true
  def handle_end_of_stream(
        _pad,
        context,
        state = %State{}
      ) do
    end_of_stream =
      if all_input_pads_received_end_of_stream?(context.pads) do
        [end_of_stream: :output]
      else
        []
      end

    {end_of_stream, state}
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end

  @impl true
  def handle_pad_removed(_pad, _ctx, state = %State{}) do
    {[], state}
  end
end
