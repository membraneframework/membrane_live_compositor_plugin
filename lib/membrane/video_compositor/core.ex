defmodule Membrane.VideoCompositor.Core do
  @moduledoc false
  # The element responsible for composing frames.

  use Membrane.Filter

  alias Membrane.{Buffer, Pad, RawVideo, Time}
  alias Membrane.VideoCompositor.{CompositorCoreFormat, Scene, WgpuAdapter}

  defmodule State do
    @moduledoc false
    # The internal state of the compositor

    @type wgpu_state() :: any()
    @type pad_id() :: non_neg_integer()
    @type pads_to_ids() :: %{Membrane.Pad.ref_t() => pad_id()}

    @type t() :: %__MODULE__{
            wgpu_state: wgpu_state(),
            input_stream_format: nil | CompositorCoreFormat.t(),
            output_stream_format: RawVideo.t(),
            scene: nil | Scene.t(),
            pads_to_ids: pads_to_ids()
          }

    @enforce_keys [:wgpu_state, :output_stream_format]
    defstruct @enforce_keys ++ [input_stream_format: nil, scene: nil, pads_to_ids: %{}]
  end

  def_options output_stream_format: [
                spec: RawVideo.t(),
                description: "Struct with video width, height, framerate and pixel format."
              ]

  def_input_pad :input,
    availability: :always,
    demand_mode: :auto,
    accepted_format: %CompositorCoreFormat{}

  def_output_pad :output,
    availability: :always,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420}

  @impl true
  def handle_init(_ctx, options) do
    {:ok, wgpu_state} = WgpuAdapter.init(options.output_stream_format)

    state = %State{
      wgpu_state: wgpu_state,
      output_stream_format: options.output_stream_format
    }

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state = %State{output_stream_format: output_stream_format}) do
    {[stream_format: {:output, output_stream_format}], state}
  end

  @impl true
  def handle_stream_format(
        _pad,
        stream_format = %CompositorCoreFormat{pads_formats: pads_formats},
        _context,
        state = %State{wgpu_state: wgpu_state}
      ) do
    pads_to_ids =
      pads_formats
      |> Map.keys()
      |> Enum.with_index(fn pad, index -> {pad, index} end)
      |> Enum.into(%{})

    if state.scene != nil do
      WgpuAdapter.set_scene(wgpu_state, stream_format, state.scene, pads_to_ids)
    end

    state = %State{state | pads_to_ids: pads_to_ids, input_stream_format: stream_format}
    {[], state}
  end

  @impl true
  def handle_process(
        _pad,
        %Buffer{pts: pts, payload: payload},
        _context,
        state = %State{wgpu_state: wgpu_state, pads_to_ids: pads_to_ids}
      ) do
    {:ok, rendered_frame} =
      payload
      |> Map.to_list()
      |> then(fn pads_frames -> send_pads_frames(wgpu_state, pads_frames, pts, pads_to_ids) end)

    output_buffer = %Buffer{pts: pts, dts: pts, payload: rendered_frame}

    {[buffer: {:output, output_buffer}], state}
  end

  @impl true
  def handle_end_of_stream(_pad, _ctx, state = %State{}) do
    {[end_of_stream: :output], state}
  end

  @impl true
  def handle_parent_notification(
        {:update_scene, scene = %Scene{}},
        _ctx,
        state = %State{
          wgpu_state: wgpu_state,
          input_stream_format: stream_format,
          pads_to_ids: pads_to_ids
        }
      ) do
    if stream_format != nil do
      WgpuAdapter.set_scene(wgpu_state, stream_format, scene, pads_to_ids)
    end

    state = %State{state | scene: scene}
    {[], state}
  end

  @spec send_pads_frames(any(), [{Pad.ref_t(), binary()}], Time.non_neg_t(), State.pads_to_ids()) ::
          {:ok, rendered_frame :: binary()} | {:error, reason :: String.t()}
  defp send_pads_frames(wgpu_state, [{pad, pad_frame} | []], pts, pads_to_ids) do
    case WgpuAdapter.process_frame(wgpu_state, Map.get(pads_to_ids, pad), {pad_frame, pts}) do
      {:ok, {frame, _pts}} ->
        {:ok, frame}

      :ok ->
        {:error, "Wgpu should render frame on last buffer!"}
    end
  end

  defp send_pads_frames(wgpu_state, [{pad, pad_frame} | tail], pts, pads_to_ids) do
    case WgpuAdapter.process_frame(wgpu_state, Map.get(pads_to_ids, pad), {pad_frame, pts}) do
      :ok ->
        send_pads_frames(wgpu_state, tail, pts, pads_to_ids)

      {:ok, {_frame, _pts}} ->
        {:error, "Wgpu should render frame only on last buffer!"}
    end
  end
end
