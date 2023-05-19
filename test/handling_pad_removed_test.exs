defmodule Membrane.VideoCompositor.HandlingPadRemovedTest do
  use ExUnit.Case

  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Core, as: VC_Core
  alias Membrane.VideoCompositor.Scene.BaseVideoPlacement
  alias Membrane.VideoCompositor.VideoTransformations

  test "when a video that did not receive start of stream gets removed it should unblock others" do
    stream_format = %RawVideo{
      width: 2,
      height: 2,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: true
    }

    init_opts = %{
      stream_format: stream_format
    }

    assert {[], state} = VC_Core.handle_init(%{}, init_opts)

    pad_added_opts = %{
      initial_placement: %BaseVideoPlacement{
        position: {0, 0},
        size: {2, 2},
        z_value: 0.0
      },
      timestamp_offset: 0,
      initial_video_transformations: VideoTransformations.empty()
    }

    assert {[stream_format: {:output, ^stream_format}], state} =
             VC_Core.handle_playing(%{}, state)

    pad1 = {Membrane.Pad, :input, 1}
    pad2 = {Membrane.Pad, :input, 2}

    assert {[], state} = VC_Core.handle_pad_added(pad1, %{options: pad_added_opts}, state)

    assert {[], state} = VC_Core.handle_stream_format(pad1, stream_format, %{}, state)
    assert {[], state} = VC_Core.handle_start_of_stream(pad1, %{}, state)

    assert {[], state} = VC_Core.handle_pad_added(pad2, %{options: pad_added_opts}, state)

    assert {[], state} = VC_Core.handle_stream_format(pad2, stream_format, %{}, state)
    assert {[], state} = VC_Core.handle_start_of_stream(pad2, %{}, state)

    second = Membrane.Time.second()
    buffer1 = %Buffer{payload: <<0::size(48)>>, pts: 0}
    assert {[], state} = VC_Core.handle_process(pad1, buffer1, %{}, state)

    buffer2 = %Buffer{payload: <<0::size(48)>>, pts: second}
    assert {[], state} = VC_Core.handle_process(pad1, buffer2, %{}, state)

    pads = %{
      pad2 => %{end_of_stream?: false}
    }

    assert {[
              {:buffer,
               [
                 %Buffer{pts: 0},
                 %Buffer{pts: ^second}
               ]}
            ], _state} = VC_Core.handle_pad_removed(pad2, %{pads: pads}, state)
  end
end
