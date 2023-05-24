defmodule Membrane.VideoCompositor.Queue.Offline.Element do
  @moduledoc """
  This module is responsible for offline queueing strategy.

  In this strategy frames are sent to the compositor only when all added input pads queues,
  with timestamp offset lower or equal to composed buffer pts,
  have at least one frame.

  This element requires all input pads to have equal fps to work properly.
  A framerate converter should be used for every input pad to synchronize the framerate.
  """

  use Membrane.Filter

  alias Membrane.VideoCompositor.Support.Pipeline.H264.ParserDecoder
  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.VideoCompositor.Queue
  alias Membrane.VideoCompositor.Queue.Offline.State, as: OfflineState
  alias Membrane.VideoCompositor.Queue.State
  alias Membrane.VideoCompositor.Queue.State.{MockCallbacks, PadState}
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  def_options output_framerate: [
                spec: RawVideo.framerate_t()
              ]

  def_input_pad :input,
    availability: :on_request,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420},
    options: [
      timestamp_offset: [
        spec: Time.non_neg_t(),
        description: "Input stream PTS offset in nanoseconds. Must be non-negative.",
        default: 0
      ],
      video_config: [
        spec: VideoConfig.t(),
        description: "Specify layout and transformations of the video on final scene."
      ],
      vc_input_ref: [
        spec: Pad.ref_t(),
        description: "Reference to VC input pad."
      ]
    ]

  def_output_pad :output,
    demand_mode: :auto,
    accepted_format: %CompositorCoreFormat{}

  @impl true
  def handle_init(
        _ctx,
        _options = %{output_framerate: output_framerate}
      ) do
    {[], %State{output_framerate: output_framerate, custom_strategy_state: %OfflineState{}}}
  end

  @impl true
  def handle_pad_added(pad, context, state = %State{}) do
    vc_input_ref = context.options.vc_input_ref

    state =
      state
      |> Bunch.Struct.put_in([:custom_strategy_state, :inputs_mapping, pad], vc_input_ref)
      |> Bunch.Struct.put_in([:pads_states, vc_input_ref], PadState.new(context.options))

    {[], state}
  end

  @impl true
  def handle_end_of_stream(
        pad,
        _ctx,
        state = %State{custom_strategy_state: %OfflineState{inputs_mapping: inputs_mapping}}
      ) do
    vc_input_ref = Map.fetch!(inputs_mapping, pad)

    state = State.put_event(state, {:end_of_stream, vc_input_ref})

    check_pads_queues({[], state})
  end

  @impl true
  def handle_stream_format(
        pad,
        stream_format,
        _context,
        state = %State{custom_strategy_state: %OfflineState{inputs_mapping: inputs_mapping}}
      ) do
    vc_input_ref = Map.fetch!(inputs_mapping, pad)

    state = State.put_event(state, {{:stream_format, stream_format}, vc_input_ref})

    {[], state}
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        state = %State{custom_strategy_state: %OfflineState{inputs_mapping: inputs_mapping}}
      ) do
    vc_input_ref = Map.fetch!(inputs_mapping, pad)

    frame_pts =
      buffer.pts + Bunch.Struct.get_in(state, [:pads_states, vc_input_ref, :timestamp_offset])

    state =
      state
      |> State.put_event({{:frame, frame_pts, buffer.payload}, vc_input_ref})
      |> Map.update!(:most_recent_frame_pts, &max(&1, frame_pts))

    check_pads_queues({[], state})
  end

  @impl true
  def handle_parent_notification(
        {:update_scene, scene = %Scene{}},
        _ctx,
        state = %State{most_recent_frame_pts: most_recent_frame_pts}
      ) do
    state = State.put_event(state, {:update_scene, most_recent_frame_pts, scene})

    {[], state}
  end

  @spec calculate_next_buffer_pts(State.t()) :: Time.non_neg_t()
  defp calculate_next_buffer_pts(%State{
         next_buffer_pts: previous_buffer_pts,
         output_framerate: {fps_num, fps_den}
       }) do
    previous_buffer_pts + Kernel.ceil(Time.seconds(1) * fps_den / fps_num)
  end

  @spec frame_or_eos(list(PadState.pad_event())) :: :neither_frame_nor_eos | :frame | :eos
  defp frame_or_eos(events_queue) do
    Enum.reduce_while(
      events_queue,
      :neither_frame_nor_eos,
      fn event, _acc ->
        case PadState.event_type(event) do
          :frame -> {:halt, :frame}
          :end_of_stream -> {:halt, :eos}
          _other -> {:cont, :neither_frame_nor_eos}
        end
      end
    )
  end

  # Returns :all_pads_eos when
  # all pads queues have :eos event without any :frame event.
  # Returns :all_pads_ready when
  # 1. at least one pad queue has frame (to avoid sending empty buffer)
  # 2. all pads queues have:
  #   a. larger timestamp offset then next buffer pts or
  #   b. at least one waiting frame or
  #   c. eos event
  @spec queues_state(State.t()) :: :all_pads_eos | :all_pads_ready | :waiting
  defp queues_state(%State{
         pads_states: pads_states,
         next_buffer_pts: buffer_pts
       }) do
    pads_states
    |> Map.values()
    |> Enum.reduce_while(
      :all_pads_eos,
      fn %PadState{timestamp_offset: timestamp_offset, events_queue: events_queue},
         current_state ->
        case frame_or_eos(events_queue) do
          :frame ->
            {:cont, :all_pads_ready}

          :eos ->
            {:cont, current_state}

          :neither_frame_nor_eos
          when timestamp_offset > buffer_pts and current_state == :all_pads_eos ->
            {:cont, :waiting}

          :neither_frame_nor_eos
          when timestamp_offset > buffer_pts and current_state == :all_pads_ready ->
            {:cont, :all_pads_ready}

          :neither_frame_nor_eos ->
            {:halt, :waiting}
        end
      end
    )
  end

  @spec check_pads_queues({Queue.compositor_actions(), State.t()}) ::
          {Queue.compositor_actions(), State.t()}
  defp check_pads_queues({actions, state = %State{}}) do
    case queues_state(state) do
      :all_pads_ready ->
        handle_events(state)
        |> then(fn {new_actions, state} -> {actions ++ new_actions, state} end)
        # In some cases, multiple buffers might be composed,
        # e.g. when dropping pad after handling :end_of_stream event on blocking pad queue
        |> check_pads_queues()

      :all_pads_eos ->
        {actions ++ [end_of_stream: :output], state}

      :waiting ->
        {actions, state}
    end
  end

  @spec handle_events(State.t()) :: {Queue.compositor_actions(), State.t()}
  defp handle_events(
         initial_state = %State{
           pads_states: pads_states,
           next_buffer_pts: buffer_pts
         }
       ) do
    state = pop_scene_events(initial_state)

    {pads_frames, new_state} =
      pads_states
      |> Map.to_list()
      |> Enum.filter(fn {_pad, %PadState{timestamp_offset: timestamp_offset}} ->
        timestamp_offset <= buffer_pts
      end)
      |> Enum.reduce(
        {%{}, state},
        fn {pad, _pad_state}, {pads_frames, state} ->
          case pop_pad_events(pad, state) do
            {{:frame, _frame_pts, frame_data}, state} ->
              {Map.put(pads_frames, pad, frame_data), state}

            {:end_of_stream, state} ->
              {pads_frames, state}
          end
        end
      )
      |> then(fn {pads_frames, state} ->
        {pads_frames, %State{state | next_buffer_pts: calculate_next_buffer_pts(state)}}
      end)

    stream_format_action =
      if new_state.current_output_format != initial_state.current_output_format do
        [stream_format: {:output, new_state.current_output_format}]
      else
        []
      end

    scene_action =
      if new_state.current_scene != initial_state.current_scene do
        [event: {:output, new_state.current_scene}]
      else
        []
      end

    buffer_action = [
      buffer: {:output, %Buffer{payload: pads_frames, pts: buffer_pts, dts: buffer_pts}}
    ]

    {stream_format_action ++ scene_action ++ buffer_action, new_state}
  end

  @spec pop_scene_events(State.t()) :: State.t()
  defp pop_scene_events(
         state = %State{
           scene_update_events: scene_update_events,
           next_buffer_pts: buffer_pts
         }
       ) do
    Enum.reduce_while(scene_update_events, state, fn {:update_scene, pts, new_scene}, state ->
      if pts < buffer_pts do
        {:cont, %State{state | current_scene: new_scene}}
      else
        {:halt, state}
      end
    end)
  end

  # Pops events from pad event queue, handles them and returns updated state
  @spec pop_pad_events(Pad.ref_t(), State.t()) ::
          {PadState.frame_event() | PadState.end_of_stream_event(), State.t()}
  defp pop_pad_events(pad, state) do
    [event | events_tail] = Bunch.Struct.get_in(state, [:pads_states, pad, :events_queue])

    state = Bunch.Struct.put_in(state, [:pads_states, pad, :events_queue], events_tail)

    case event do
      {:frame, _pts, _frame_data} = frame_event ->
        {frame_event, state}

      :end_of_stream ->
        state =
          state
          |> MockCallbacks.remove_video(pad)
          |> Bunch.Struct.delete_in([:current_output_format, :pad_formats, pad])
          |> Bunch.Struct.delete_in([:pads_states, pad])

        {:end_of_stream, state}

      {:pad_added, pad_options} ->
        state = MockCallbacks.add_video(state, pad, pad_options)
        pop_pad_events(pad, state)

      {:stream_format, stream_format} ->
        state =
          Bunch.Struct.put_in(state, [:current_output_format, :pad_formats, pad], stream_format)

        pop_pad_events(pad, state)
    end
  end
end
