defmodule Membrane.VideoCompositor.Core do
  @moduledoc false
  # The element responsible for composing frames.

  use Membrane.Filter

  alias Membrane.VideoCompositor.SceneChangeEvent
  alias Membrane.{Buffer, RawVideo, Time}
  alias Membrane.VideoCompositor.{CompositorCoreFormat, Scene, SceneChangeEvent, WgpuAdapter}

  defmodule State do
    @moduledoc false
    # The internal state of the compositor

    @enforce_keys [:wgpu_state, :output_stream_format]
    defstruct @enforce_keys ++
                [input_stream_format: nil, scene: nil, pads_to_ids: %{}, update_videos?: true]

    @type wgpu_state() :: any()
    @type pad_id() :: non_neg_integer()
    @type pads_to_ids() :: %{Membrane.Pad.ref_t() => pad_id()}

    @type t() :: %__MODULE__{
            wgpu_state: wgpu_state(),
            input_stream_format: nil | CompositorCoreFormat.t(),
            output_stream_format: RawVideo.t(),
            scene: nil | Scene.t(),
            pads_to_ids: pads_to_ids(),
            update_videos?: boolean()
          }
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
        stream_format = %CompositorCoreFormat{pad_formats: pad_formats},
        _context,
        state = %State{}
      ) do
    pads_to_ids =
      pad_formats
      |> Map.keys()
      |> Enum.with_index(fn pad, index -> {pad, index} end)
      |> Enum.into(%{})

    state = %State{
      state
      | pads_to_ids: pads_to_ids,
        input_stream_format: stream_format,
        update_videos?: true
    }

    {[], state}
  end

  @impl true
  def handle_process(
        _pad,
        %Buffer{pts: pts, payload: payload},
        _context,
        state = %State{
          pads_to_ids: pads_to_ids,
          wgpu_state: wgpu_state,
          scene: scene,
          input_stream_format: stream_format,
          update_videos?: update_videos?,
          output_stream_format: output_stream_format
        }
      ) do
    if payload == %{} do
      buffer = %Buffer{pts: pts, dts: pts, payload: get_blank_frame(output_stream_format)}

      {[buffer: {:output, buffer}], state}
    else
      if update_videos? do
        input_pads = pads_to_ids |> Map.keys() |> MapSet.new()

        CompositorCoreFormat.validate(stream_format, input_pads)
        Scene.validate(scene, input_pads)

        :ok = WgpuAdapter.set_videos(wgpu_state, stream_format, scene, pads_to_ids)
      end

      {:ok, rendered_frame} =
        if payload == %{} do
          {:ok, get_blank_frame(output_stream_format)}
        else
          payload
          |> Map.to_list()
          |> Enum.map(fn {pad, frame} -> {Map.fetch!(pads_to_ids, pad), frame, pts} end)
          |> then(fn pads_frames -> send_pads_frames(wgpu_state, pads_frames) end)
        end

      output_buffer = %Buffer{pts: pts, dts: pts, payload: rendered_frame}

      {[buffer: {:output, output_buffer}], %State{state | update_videos?: false}}
    end
  end

  @impl true
  def handle_end_of_stream(_pad, _ctx, state = %State{}) do
    {[end_of_stream: :output], state}
  end

  @impl true
  def handle_event(_pad, %SceneChangeEvent{new_scene: scene = %Scene{}}, _ctx, state) do
    {[], %State{state | scene: scene, update_videos?: true}}
  end

  @spec send_pads_frames(
          State.wgpu_state(),
          [{pad_id :: State.pad_id(), frame :: binary(), pts :: Time.non_neg_t()}]
        ) :: {:ok, rendered_frame :: binary()}
  defp send_pads_frames(wgpu_state, [{pad, pad_frame, pts}]) do
    case WgpuAdapter.process_frame(wgpu_state, pad, {pad_frame, pts}) do
      {:ok, {frame, _pts}} ->
        {:ok, frame}

      :ok ->
        raise "Core should render frame on last buffer"
    end
  end

  defp send_pads_frames(wgpu_state, [{pad, pad_frame, pts} | tail]) do
    case WgpuAdapter.process_frame(wgpu_state, pad, {pad_frame, pts}) do
      :ok ->
        send_pads_frames(wgpu_state, tail)

      {:ok, {_frame, _pts}} ->
        raise "Core should render frame only on last buffer"
    end
  end

  @spec get_blank_frame(RawVideo.t()) :: binary()
  def get_blank_frame(%RawVideo{width: width, height: height}) do
    :binary.copy(<<16>>, height * width) <>
      :binary.copy(<<128>>, height * width)
  end
end
