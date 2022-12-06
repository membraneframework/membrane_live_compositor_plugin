defmodule Membrane.VideoCompositor.CompositorElement do
  @moduledoc """
  The element responsible for composing frames.

  It is capable of operating in one of two modes:

   * offline compositing:
     The compositor will wait for all videos to have a recent enough frame available and then perform the compositing.

   * real-time compositing:
     In this mode, if the compositor will start a timer ticking every spf (seconds per frame). The timer is reset every time a frame is produced.
     If the compositor doesn't have all frames ready by the time the timer ticks, it will produce a frame anyway, using old frames as fallback in cases when a current frame is not available.
     If the frames arrive later, they will be dropped. The newest dropped frame will become the new fallback frame.

  """

  use Membrane.Filter
  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.RustStructs.VideoLayout
  alias Membrane.VideoCompositor.Wgpu

  @typedoc """
  A unique name used to identify videos.
  """
  @type name_t :: any()

  def_options caps: [
                spec: RawVideo.t(),
                description: "Struct with video width, height, framerate and pixel format."
              ],
              real_time: [
                spec: boolean(),
                description: """
                Set the compositor to real-time mode.
                """,
                default: false
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    availability: :on_request,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420},
    options: [
      initial_layout: [
        spec: VideoLayout.t(),
        description: "Initial layout of the video on the screen"
      ],
      name: [
        spec: name_t(),
        description: "A unique identifier for the video coming through this pad",
        default: nil
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}

  @impl true
  def handle_init(options) do
    {:ok, wgpu_state} = Wgpu.init(options.caps)

    state = %{
      initial_video_layouts: %{},
      names_to_pads: %{},
      caps: options.caps,
      real_time: options.real_time,
      wgpu_state: wgpu_state,
      pads_to_ids: %{},
      new_pad_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    spf = spf_from_framerate(state.caps.framerate)

    actions =
      if state.real_time do
        [start_timer: {:render_frame, spf}, caps: {:output, state.caps}]
      else
        [caps: {:output, state.caps}]
      end

    {{:ok, actions}, state}
  end

  @impl true
  def handle_tick(:render_frame, _ctx, state) do
    {:ok, {frame, pts}} = Wgpu.force_render(state.wgpu_state)

    actions = [buffer: {:output, %Buffer{payload: frame, pts: pts}}]

    {{:ok, actions}, state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    initial_layout = context.options.initial_layout
    name = if context.options.name != nil, do: context.options.name, else: make_ref()

    state = register_pad(state, name, pad, initial_layout)
    {:ok, state}
  end

  defp register_pad(state, name, pad, layout) do
    new_id = state.new_pad_id

    %{
      state
      | initial_video_layouts: Map.put(state.initial_video_layouts, new_id, layout),
        names_to_pads: Map.put(state.names_to_pads, name, pad),
        pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      initial_video_layouts: initial_video_layouts
    } = state

    id = Map.get(pads_to_ids, pad)

    {layout, initial_video_layouts} = Map.pop(initial_video_layouts, id)

    if layout == nil do
      # this video was added before
      :ok = Wgpu.update_caps(wgpu_state, id, caps)
    else
      # this video was waiting for first caps to be added to the compositor
      :ok = Wgpu.add_video(wgpu_state, id, caps, layout)
    end

    {:ok, %{state | initial_video_layouts: initial_video_layouts}}
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        state
      ) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state
    } = state

    id = Map.get(pads_to_ids, pad)

    %Membrane.Buffer{payload: frame, pts: pts} = buffer

    case Wgpu.upload_frame(wgpu_state, id, {frame, pts}) do
      {:ok, {frame, pts}} ->
        {
          {
            :ok,
            [
              buffer: {
                :output,
                %Membrane.Buffer{payload: frame, pts: pts}
              }
            ] ++ restart_timer_action_if_necessary(state)
          },
          state
        }

      :ok ->
        {:ok, state}
    end
  end

  defp spf_from_framerate({frames, seconds}) do
    Ratio.new(frames, seconds)
  end

  defp restart_timer_action_if_necessary(state) do
    spf = spf_from_framerate(state.caps.framerate)

    if state.real_time do
      [stop_timer: :render_frame, start_timer: {:render_frame, spf}]
    else
      []
    end
  end

  @impl true
  def handle_end_of_stream(
        pad,
        context,
        state
      ) do
    %{pads_to_ids: pads_to_ids, wgpu_state: wgpu_state} = state
    id = Map.get(pads_to_ids, pad)

    :ok = Wgpu.send_end_of_stream(wgpu_state, id)

    actions =
      if all_input_pads_received_end_of_stream?(context.pads) do
        stop = if state.real_time, do: [stop_timer: :render_frame], else: []
        [end_of_stream: :output] ++ stop
      else
        []
      end

    {{:ok, actions}, state}
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end

  @impl true
  def handle_other({:update_layout, layouts}, _ctx, state) do
    %{
      names_to_pads: names_to_pads,
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state
    } = state

    for {name, layout} <- layouts do
      pad = Map.get(names_to_pads, name)
      id = Map.get(pads_to_ids, pad)

      Wgpu.update_layout(wgpu_state, id, layout)
    end

    {:ok, state}
  end
end
