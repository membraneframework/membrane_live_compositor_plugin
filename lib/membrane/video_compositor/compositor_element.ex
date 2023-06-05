defmodule Membrane.VideoCompositor.CompositorElement do
  @moduledoc false
  # The element responsible for composing frames.

  #  Right now, the compositor only operates in offline mode, which means that it will wait for
  #  all videos to have a recent enough frame available, however long it might take, and then perform the compositing.

  use Membrane.Filter

  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Object.Layout
  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.Transformation
  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.WgpuAdapter

  defmodule State do
    @moduledoc false
    # The internal state of the compositor

    defmodule VideoInformation do
      @moduledoc false
      # Information required for adding a video to the compositor except the stream format

      @type t() :: %__MODULE__{
              initial_placement: BaseVideoPlacement.t(),
              initial_video_transformations: VideoTransformations.t()
            }

      @enforce_keys [:initial_placement, :initial_video_transformations]
      defstruct @enforce_keys
    end

    @type wgpu_state_t() :: any()
    @type pad_id_t() :: non_neg_integer()
    @type pads_to_ids_t() :: %{Membrane.Pad.ref_t() => pad_id_t()}
    @type timestamp_offsets_t() :: %{pad_id_t() => Membrane.Time.t()}
    @type videos_waiting_for_stream_format_t() :: %{optional(pad_id_t()) => VideoInformation.t()}

    @type t() :: %__MODULE__{
            wgpu_state: wgpu_state_t(),
            new_compositor_state: WgpuAdapter.new_compositor_state(),
            stream_format: RawVideo.t(),
            new_pad_id: pad_id_t(),
            pads_to_ids: pads_to_ids_t(),
            timestamp_offsets: timestamp_offsets_t(),
            videos_waiting_for_stream_format: videos_waiting_for_stream_format_t()
          }

    @enforce_keys [:wgpu_state, :new_compositor_state, :stream_format]
    defstruct [
      :wgpu_state,
      :new_compositor_state,
      :stream_format,
      new_pad_id: 0,
      pads_to_ids: %{},
      timestamp_offsets: %{},
      videos_waiting_for_stream_format: %{}
    ]
  end

  def_options stream_format: [
                spec: RawVideo.t(),
                description: "Struct with video width, height, framerate and pixel format."
              ],
              transformations: [
                spec: list(Transformation.transformation_module()),
                description: """
                A list of modules that implement the Membrane.VideoCompositor.Transformation behaviour.
                These modules can later be used in the scene passed to this compositor.
                """
              ],
              layouts: [
                spec: list(Layout.layout_module()),
                description: """
                A list of modules that implement the Membrane.VideoCompositor.Layout behaviour.
                These modules can later be used in the scene passed to this compositor.
                """
              ]

  def_input_pad :input,
    availability: :on_request,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420},
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
        # Membrane Core uses macro with a quote on def_input_pad, which breaks structured data like structs.
        # To avoid that, we would need to use Macro.escape(%VideoTransformations{texture_transformations: []})
        # here and handle its mapping letter, which is a significantly harder and less readable than handling nil
        # as a default value, that's why we use nil here.
        default: nil
      ]
    ]

  def_output_pad :output,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420}

  @impl true
  def handle_init(_ctx, options) do
    {:ok, wgpu_state} = WgpuAdapter.init(options.stream_format)
    new_compositor_state = WgpuAdapter.init_new_compositor()

    WgpuAdapter.register_transformations(new_compositor_state, options.transformations)
    WgpuAdapter.register_layouts(new_compositor_state, options.layouts)

    state = %State{
      wgpu_state: wgpu_state,
      new_compositor_state: new_compositor_state,
      stream_format: options.stream_format
    }

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state = %State{}) do
    {[stream_format: {:output, state.stream_format}], state}
  end

  @impl true
  def handle_pad_added(pad, context, state = %State{}) do
    timestamp_offset =
      case context.options.timestamp_offset do
        timestamp_offset when timestamp_offset < 0 ->
          raise ArgumentError,
            message:
              "Invalid timestamp_offset option for pad: #{Pad.name_by_ref(pad)}. timestamp_offset can't be negative."

        timestamp_offset ->
          timestamp_offset
      end

    initial_placement = context.options.initial_placement

    initial_transformations =
      case context.options.initial_video_transformations do
        nil ->
          VideoTransformations.empty()

        _other ->
          context.options.initial_video_transformations
      end

    video_information = %State.VideoInformation{
      initial_placement: initial_placement,
      initial_video_transformations: initial_transformations
    }

    state = register_pad(state, pad, video_information, timestamp_offset)
    {[], state}
  end

  @spec register_pad(
          State.t(),
          Membrane.Pad.ref_t(),
          State.VideoInformation.t(),
          Membrane.Time.t()
        ) :: State.t()
  defp register_pad(state, pad, video_information, timestamp_offset) do
    new_id = state.new_pad_id

    %State{
      state
      | videos_waiting_for_stream_format:
          Map.put(state.videos_waiting_for_stream_format, new_id, video_information),
        timestamp_offsets: Map.put(state.timestamp_offsets, new_id, timestamp_offset),
        pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }
  end

  @impl true
  def handle_stream_format(pad, stream_format, _context, state = %State{}) do
    %State{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      videos_waiting_for_stream_format: videos_waiting_for_stream_format
    } = state

    id = Map.get(pads_to_ids, pad)

    videos_waiting_for_stream_format =
      case Map.pop(videos_waiting_for_stream_format, id) do
        {nil, videos_waiting_for_stream_format} ->
          # this video was added before
          :ok = WgpuAdapter.update_stream_format(wgpu_state, id, stream_format)
          videos_waiting_for_stream_format

        {%State.VideoInformation{
           initial_placement: placement,
           initial_video_transformations: transformations
         }, videos_waiting_for_stream_format} ->
          # this video was waiting for first stream_format to be added to the compositor
          :ok = WgpuAdapter.add_video(wgpu_state, id, stream_format, placement, transformations)
          videos_waiting_for_stream_format
      end

    {
      [],
      %State{
        state
        | videos_waiting_for_stream_format: videos_waiting_for_stream_format
      }
    }
  end

  @impl true
  def handle_process(pad, buffer, _context, state = %State{}) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      timestamp_offsets: timestamp_offsets
    } = state

    id = Map.get(pads_to_ids, pad)

    %Membrane.Buffer{payload: frame, pts: pts} = buffer
    pts = pts + Map.get(timestamp_offsets, id)

    case WgpuAdapter.process_frame(wgpu_state, id, {frame, pts}) do
      {:ok, {frame, pts}} ->
        {[buffer: {:output, %Membrane.Buffer{payload: frame, pts: pts}}], state}

      :ok ->
        {[], state}
    end
  end

  @impl true
  def handle_end_of_stream(
        pad,
        context,
        state = %State{}
      ) do
    %{pads_to_ids: pads_to_ids, wgpu_state: wgpu_state} = state
    id = Map.get(pads_to_ids, pad)

    {:ok, frames} = WgpuAdapter.send_end_of_stream(wgpu_state, id)

    buffers = frames |> Enum.map(fn {frame, pts} -> %Buffer{payload: frame, pts: pts} end)

    buffers = [buffer: {:output, [buffers]}]

    end_of_stream =
      if all_input_pads_received_end_of_stream?(context.pads) do
        [end_of_stream: :output]
      else
        []
      end

    actions = buffers ++ end_of_stream

    {actions, state}
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end

  @impl true
  def handle_pad_removed(pad, ctx, state = %State{}) do
    {pad_id, pads_to_ids} = Map.pop!(state.pads_to_ids, pad)
    state = %{state | pads_to_ids: pads_to_ids}

    if is_pad_waiting_for_stream_format?(pad, state) do
      # This is the case of removing a video that did not receive caps yet.
      # Since it did not receive stream format, it wasn't added to the internal
      # compositor state yet.
      {[],
       %State{
         state
         | videos_waiting_for_stream_format:
             Map.delete(state.videos_waiting_for_stream_format, pad_id)
       }}
    else
      if Map.get(ctx.pads, pad).end_of_stream? do
        # Videos that already received end of stream don't require special treatment
        {[], state}
      else
        # This is the case of removing a video that did receive stream format, but did
        # not receive end of stream. All videos that were added to the compositor need
        # to receive end of stream, so we need to send one here.
        {:ok, frames} = WgpuAdapter.send_end_of_stream(state.wgpu_state, pad_id)

        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        buffers = frames |> Enum.map(fn {frame, pts} -> %Buffer{payload: frame, pts: pts} end)

        {[buffer: buffers], state}
      end
    end
  end

  @spec is_pad_waiting_for_stream_format?(Membrane.Pad.ref_t(), State.t()) :: boolean()
  defp is_pad_waiting_for_stream_format?(pad, state) do
    pad_id = Map.get(state.pads_to_ids, pad)

    Map.has_key?(state.videos_waiting_for_stream_format, pad_id)
  end

  @impl true
  def handle_parent_notification({:update_placement, placements}, _ctx, state = %State{}) do
    %State{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      videos_waiting_for_stream_format: videos_waiting_for_stream_format
    } = state

    videos_waiting_for_stream_format =
      update_placements(placements, pads_to_ids, wgpu_state, videos_waiting_for_stream_format)

    {[], %State{state | videos_waiting_for_stream_format: videos_waiting_for_stream_format}}
  end

  @impl true
  def handle_parent_notification(
        {:update_transformations, all_transformations},
        _ctx,
        state = %State{}
      ) do
    %State{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      videos_waiting_for_stream_format: videos_waiting_for_stream_format
    } = state

    videos_waiting_for_stream_format =
      update_transformations(
        all_transformations,
        pads_to_ids,
        wgpu_state,
        videos_waiting_for_stream_format
      )

    {[], %State{state | videos_waiting_for_stream_format: videos_waiting_for_stream_format}}
  end

  @spec update_placements(
          [{Membrane.Pad.ref_t(), BaseVideoPlacement.t()}],
          State.pads_to_ids_t(),
          State.wgpu_state_t(),
          State.videos_waiting_for_stream_format_t()
        ) :: State.videos_waiting_for_stream_format_t()
  defp update_placements(
         [],
         _pads_to_ids,
         _wgpu_state,
         videos_waiting_for_stream_format
       ) do
    videos_waiting_for_stream_format
  end

  defp update_placements(
         [{pad, placement} | other_placements],
         pads_to_ids,
         wgpu_state,
         videos_waiting_for_stream_format
       ) do
    id = Map.get(pads_to_ids, pad)

    videos_waiting_for_stream_format =
      case WgpuAdapter.update_placement(wgpu_state, id, placement) do
        :ok ->
          videos_waiting_for_stream_format

        # in case of update_placements is called before handle_stream_format and add_video in rust
        # wasn't called yet (the video wasn't registered in rust yet)
        {:error, :bad_video_index} ->
          Map.update!(
            videos_waiting_for_stream_format,
            id,
            fn information = %State.VideoInformation{} ->
              %State.VideoInformation{information | initial_placement: placement}
            end
          )
      end

    update_placements(other_placements, pads_to_ids, wgpu_state, videos_waiting_for_stream_format)
  end

  @spec update_transformations(
          [{Membrane.Pad.ref_t(), VideoTransformations.t()}],
          State.pads_to_ids_t(),
          State.wgpu_state_t(),
          State.videos_waiting_for_stream_format_t()
        ) :: State.videos_waiting_for_stream_format_t()
  defp update_transformations(
         [],
         _pads_to_ids,
         _wgpu_state,
         videos_waiting_for_stream_format
       ) do
    videos_waiting_for_stream_format
  end

  defp update_transformations(
         [{pad, video_transformations} | other_transformations],
         pads_to_ids,
         wgpu_state,
         videos_waiting_for_stream_format
       ) do
    id = Map.get(pads_to_ids, pad)

    videos_waiting_for_stream_format =
      case WgpuAdapter.update_transformations(wgpu_state, id, video_transformations) do
        :ok ->
          videos_waiting_for_stream_format

        # in case of update_transformations is called before handle_stream_format and add_video in rust
        # wasn't called yet (the video wasn't registered in rust yet)
        {:error, :bad_video_index} ->
          Map.update!(
            videos_waiting_for_stream_format,
            id,
            fn information = %State.VideoInformation{} ->
              %State.VideoInformation{
                information
                | initial_video_transformations: video_transformations
              }
            end
          )
      end

    update_transformations(
      other_transformations,
      pads_to_ids,
      wgpu_state,
      videos_waiting_for_stream_format
    )
  end
end
