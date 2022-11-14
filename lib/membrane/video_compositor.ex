defmodule Membrane.VideoCompositor do
  @moduledoc """
  The element responsible for placing the first received frame
  above the other and sending forward buffer with
  merged frame binary in the payload.
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Wgpu

  def_options caps: [
                type: RawVideo,
                description: "Struct with video width, height, framerate and pixel format."
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    availability: :on_request,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420},
    options: [
      position: [
        type: :tuple,
        spec: {integer(), integer()},
        description:
          "Initial position of the video on the screen, given in the pixels,
          relative to the upper left corner of the screen",
        default: {0, 0}
      ],
      z_value: [
        type: :float,
        spec: float(),
        description:
          "Specify which video should be on top of the others. Should be in (0, 1) range.
          Videos with higher z_value will be displayed on top.",
        default: 0.0
      ],
      scale: [
        type: :float,
        spec: float(),
        description: "Video scale factor.",
        default: 1.0
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
      video_positions_waiting_for_caps: %{},
      video_z_values_waiting_for_caps: %{},
      video_scales_waiting_for_caps: %{},
      caps: options.caps,
      wgpu_state: wgpu_state,
      pads_to_ids: %{},
      new_pad_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, state.caps}}, state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    position = context.options.position
    z_value = context.options.z_value
    scale = context.options.scale

    state = register_pad(state, pad, position, z_value, scale)
    {:ok, state}
  end

  defp register_pad(state, pad, position, z_value, scale) do
    new_id = state.new_pad_id

    %{
      state
      | video_positions_waiting_for_caps:
          Map.put(state.video_positions_waiting_for_caps, new_id, position),
        video_z_values_waiting_for_caps:
          Map.put(state.video_z_values_waiting_for_caps, new_id, z_value),
        video_scales_waiting_for_caps:
          Map.put(state.video_scales_waiting_for_caps, new_id, scale),
        pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      wgpu_state: wgpu_state,
      video_positions_waiting_for_caps: video_positions_waiting_for_caps,
      video_z_values_waiting_for_caps: video_z_values_waiting_for_caps,
      video_scales_waiting_for_caps: video_scales_waiting_for_caps
    } = state

    id = Map.get(pads_to_ids, pad)

    {position, video_positions_waiting_for_caps} = Map.pop!(video_positions_waiting_for_caps, id)
    {:ok, wgpu_state} = Wgpu.add_video(wgpu_state, id, caps, position)

    state = %{
      state
      | wgpu_state: wgpu_state,
        video_positions_waiting_for_caps: video_positions_waiting_for_caps,
        video_z_values_waiting_for_caps: video_z_values_waiting_for_caps,
        video_scales_waiting_for_caps: video_scales_waiting_for_caps
    }

    {:ok, state}
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
      {{:ok, {frame, pts}}, wgpu_state} ->
        {
          {
            :ok,
            buffer: {
              :output,
              %Membrane.Buffer{payload: frame, pts: pts}
            }
          },
          %{state | wgpu_state: wgpu_state}
        }

      {:ok, wgpu_state} ->
        {:ok, %{state | wgpu_state: wgpu_state}}
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

    {:ok, wgpu_state} = Wgpu.send_end_of_stream(wgpu_state, id)
    state = %{state | wgpu_state: wgpu_state}

    if all_input_pads_received_end_of_stream?(context.pads) do
      {{:ok, end_of_stream: :output}, state}
    else
      {:ok, state}
    end
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end
end
