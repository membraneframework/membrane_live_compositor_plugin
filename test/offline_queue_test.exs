defmodule Membrane.VideoCompositor.OfflineQueueTest do
  @moduledoc false
  use ExUnit.Case

  alias Membrane.VideoCompositor.CompositorCoreFormat
  alias Membrane.{Buffer, Pad, RawVideo}
  alias Membrane.VideoCompositor.Queue.Offline.Element, as: OfflineQueue
  alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.VideoConfig

  @frame <<0::3_110_400>>

  @buffer %Buffer{
    pts: 0,
    dts: 0,
    payload: @frame
  }

  @video_config %VideoConfig{
    placement: %BaseVideoPlacement{
      position: {0, 0},
      size: {1.0, 1.0}
    }
  }

  @video_stream_format %RawVideo{
    width: 16,
    height: 9,
    framerate: {1, 1},
    pixel_format: :I420,
    aligned: true
  }

  @pad1 {Pad, :input, 1}
  @pad2 {Pad, :input, 2}

  @pad2_ts_offset 1_000_000_001

  test "Check updating stream format and scene on send buffer" do
    state = setup_videos()

    stream_format_action = [
      stream_format:
        {:compositor_core, %CompositorCoreFormat{pads_formats: %{@pad1 => @video_stream_format}}}
    ]

    scene_action = [
      notify_child:
        {:compositor, {:update_scene, %Scene{videos_configs: %{@pad1 => @video_config}}}}
    ]

    first_output_buffer = %Buffer{
      pts: 0,
      dts: 0,
      payload: %{@pad1 => @frame}
    }

    buffer_action = [
      buffer: {:compositor_core, first_output_buffer}
    ]

    actions = stream_format_action ++ scene_action ++ buffer_action
    {^actions, _state} = OfflineQueue.handle_process(@pad1, @buffer, %{}, state)
  end

  # test "Removed pad doesn't block queue" do
  #   state = setup_videos()

  #   {actions, state} = OfflineQueue.handle_pad_removed(@pad2, %{}, state)
  # end

  defp setup_videos() do
    pad1_options = %{video_config: @video_config, timestamp_offset: 0}
    pad2_options = %{video_config: @video_config, timestamp_offset: @pad2_ts_offset}

    assert {[], state} = OfflineQueue.handle_init(%{}, %{target_fps: {1, 1}})

    assert {[], state} = OfflineQueue.handle_pad_added(@pad1, %{options: pad1_options}, state)

    assert {[], state} =
             OfflineQueue.handle_stream_format(@pad1, @video_stream_format, %{}, state)

    assert {[], state} = OfflineQueue.handle_pad_added(@pad2, %{options: pad2_options}, state)

    assert {[], state} =
             OfflineQueue.handle_stream_format(@pad2, @video_stream_format, %{}, state)

    state
  end
end
