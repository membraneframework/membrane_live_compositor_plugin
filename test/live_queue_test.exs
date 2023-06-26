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

  alias Membrane.VideoCompositor.Queue.Live, as: LiveQueue

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

  @pad2_pts_offset Time.seconds(1) + 1

  test "if sets up correctly" do
    setup_videos()
  end

  test "if sends correct scene and stream format actions before buffers" do
    state = setup_videos()

    pad1_frame = <<1>>
    pad2_frame = <<2>>

    assert {[], state} =
             LiveQueue.handle_process(
               @pad1,
               %Buffer{payload: pad1_frame, pts: 0, dts: 0},
               %{},
               state
             )

    assert {[], state} =
             LiveQueue.handle_process(
               @pad2,
               %Buffer{payload: pad2_frame, pts: 0, dts: 0},
               %{},
               state
             )

    stream_format = %CompositorCoreFormat{
      pad_formats: %{@pad1 => @video_stream_format, @pad2 => @video_stream_format}
    }

    stream_format_action = {:stream_format, {:output, stream_format}}

    scene = %Scene{video_configs: %{@pad1 => @video_config, @pad2 => @video_config}}
    scene_action = {:event, {:output, %SceneChangeEvent{new_scene: scene}}}

    buffer = %Buffer{payload: %{@pad1 => pad1_frame, @pad2 => pad2_frame}, pts: 0, dts: 0}
    buffer_action = {:buffer, {:output, buffer}}

    {actions, _state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)
    assert ^stream_format_action = Enum.at(actions, 0)
    assert ^scene_action = Enum.at(actions, 1)
    assert ^buffer_action = Enum.at(actions, 2)
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
             LiveQueue.handle_process(
               @pad1,
               %Buffer{payload: <<1>>, pts: Membrane.Time.seconds(2)},
               %{},
               state
             )

    assert {[], state} = LiveQueue.handle_end_of_stream(@pad1, %{}, state)
    assert {[], state} = LiveQueue.handle_end_of_stream(@pad2, %{}, state)

    {actions, state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)

    is_eos_action? = fn action ->
      case action do
        {:end_of_stream, _} -> true
        _other -> false
      end
    end

    assert not Enum.any?(actions, is_eos_action?)

    {actions, _state} = LiveQueue.handle_tick(:buffer_scheduler, %{}, state)
    assert actions |> Enum.at(-1) |> is_eos_action?.()
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
               %{options: pad1_options},
               state
             )

    assert {[], state} = LiveQueue.handle_stream_format(@pad1, @video_stream_format, %{}, state)

    assert {[], state} =
             LiveQueue.handle_pad_added(
               @pad2,
               %{options: pad2_options},
               state
             )

    assert {[], state} = LiveQueue.handle_stream_format(@pad2, @video_stream_format, %{}, state)

    state
  end
end
