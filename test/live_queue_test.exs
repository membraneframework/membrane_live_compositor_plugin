defmodule Membrane.VideoCompositor.LiveQueueTest do
  @moduledoc false
  use ExUnit.Case

  alias Membrane.{Buffer, RawVideo, Time, VideoCompositor}

  alias Membrane.VideoCompositor.{
    BaseVideoPlacement,
    CompositorCoreFormat,
    Scene,
    SceneChangeEvent,
    VideoConfig
  }

  alias Membrane.VideoCompositor.Queue.Strategy.Live, as: LiveQueue

  alias Membrane.VideoCompositor.Support.Handler

  @video_config %VideoConfig{
    placement: %BaseVideoPlacement{
      position: {0, 0},
      size: {1.0, 1.0}
    }
  }

  @video_stream_format %RawVideo{
    width: 1920,
    height: 1080,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @pad1 {Pad, :input, 1}
  @pad2 {Pad, :input, 2}

  @pad1_frame <<1>>
  @pad2_frame <<2>>

  @pad2_pts_offset Time.seconds(1) + 1

  test "if sets up correctly" do
    setup_videos()
  end

  test "if sends correct scene and stream format actions before buffers" do
    state = setup_videos() |> send_both_pads_frames()

    stream_format = %CompositorCoreFormat{
      pad_formats: %{@pad1 => @video_stream_format, @pad2 => @video_stream_format}
    }

    stream_format_action = {:stream_format, {:output, stream_format}}

    scene = %Scene{video_configs: %{@pad1 => @video_config, @pad2 => @video_config}}
    scene_action = {:event, {:output, %SceneChangeEvent{new_scene: scene}}}

    buffer = %Buffer{payload: %{@pad1 => @pad1_frame, @pad2 => @pad2_frame}, pts: 0, dts: 0}
    buffer_action = {:buffer, {:output, buffer}}

    {actions, _state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)
    assert ^stream_format_action = Enum.at(actions, 0)
    assert ^scene_action = Enum.at(actions, 1)
    assert ^buffer_action = Enum.at(actions, 2)
  end

  test "if sends stream format and scene only once" do
    state = setup_videos() |> send_both_pads_frames()

    {actions_1, state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)
    {actions_2, state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)
    {actions_3, _state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)

    get_buffer_action = fn pts ->
      buffer = %Buffer{
        payload: %{@pad1 => @pad1_frame, @pad2 => @pad2_frame},
        pts: pts,
        dts: pts
      }

      {:buffer, {:output, buffer}}
    end

    assert Enum.count(actions_1, fn action -> action_type(action) == :stream_format end) == 1
    assert Enum.count(actions_1, fn action -> action_type(action) == :scene end) == 1

    buffer1_action = get_buffer_action.(Membrane.Time.second())
    buffer2_action = get_buffer_action.(Membrane.Time.seconds(2))

    assert [^buffer1_action] = actions_2
    assert [^buffer2_action] = actions_3
  end

  test "if sends EOS after receiving EOS from all pads" do
    state = setup_videos()

    assert {[], state} = LiveQueue.handle_end_of_stream(@pad1, %{}, state)
    assert {[], state} = LiveQueue.handle_end_of_stream(@pad2, %{}, state)

    eos_action = {:end_of_stream, :output}

    {actions, _state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)

    assert ^eos_action = Enum.at(actions, -1)
  end

  test "if sends EOS only after last frame pts" do
    state = setup_videos()

    assert {[], state} =
             LiveQueue.handle_buffer(
               @pad1,
               %Buffer{payload: <<1>>, pts: Membrane.Time.seconds(2)},
               %{},
               state
             )

    assert {[], state} = LiveQueue.handle_end_of_stream(@pad1, %{}, state)
    assert {[], state} = LiveQueue.handle_end_of_stream(@pad2, %{}, state)

    {actions, state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)

    assert not Enum.any?(actions, fn action -> action_type(action) == :eos end)

    {actions, _state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)
    assert actions |> Enum.at(-1) |> then(fn action -> action_type(action) == :eos end)
  end

  defp setup_videos() do
    pad1_options = %{metadata: @video_config, timestamp_offset: 0, vc_input_ref: @pad1}

    pad2_options = %{
      metadata: @video_config,
      timestamp_offset: @pad2_pts_offset,
      vc_input_ref: @pad2
    }

    assert {[], state} =
             LiveQueue.handle_init(%{}, %{
               vc_init_options: %VideoCompositor{
                 output_stream_format: @video_stream_format,
                 queuing_strategy: %Membrane.VideoCompositor.QueueingStrategy.Live{latency: 100},
                 handler: Handler,
                 metadata: nil
               }
             })

    assert {[], state} =
             LiveQueue.handle_pad_added(
               @pad1,
               %{pad_options: pad1_options},
               state
             )

    assert {[], state} = LiveQueue.handle_stream_format(@pad1, @video_stream_format, %{}, state)

    assert {[{:start_timer, {:initializer, 100}}], state} =
             LiveQueue.handle_start_of_stream(@pad1, %{}, state)

    assert {[], state} =
             LiveQueue.handle_pad_added(
               @pad2,
               %{pad_options: pad2_options},
               state
             )

    assert {[], state} = LiveQueue.handle_stream_format(@pad2, @video_stream_format, %{}, state)
    assert {[], state} = LiveQueue.handle_start_of_stream(@pad2, %{}, state)

    state
  end

  defp send_both_pads_frames(state) do
    assert {[], state} =
             LiveQueue.handle_buffer(
               @pad1,
               %Buffer{payload: @pad1_frame, pts: 0, dts: 0},
               %{},
               state
             )

    assert {[], state} =
             LiveQueue.handle_buffer(
               @pad2,
               %Buffer{payload: @pad2_frame, pts: 0, dts: 0},
               %{},
               state
             )

    state
  end

  defp action_type(action) do
    case action do
      {:buffer, {:output, buffer}} when is_map(buffer) ->
        :buffer

      {:end_of_stream, :output} ->
        :eos

      {:event, {:output, %SceneChangeEvent{new_scene: %Scene{}}}} ->
        :scene

      {:stream_format, {:output, %CompositorCoreFormat{pad_formats: pad_formats}}}
      when is_map(pad_formats) ->
        :stream_format

      {:start_composing, _} ->
        :start_composing

      {:stop_timer, _} ->
        :stop_timer

      _other ->
        raise "Unknown action"
    end
  end
end
