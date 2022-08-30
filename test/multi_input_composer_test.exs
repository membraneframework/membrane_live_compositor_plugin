defmodule Membrane.VideoCompositor.Test.MultiInputComposerTest do
  use ExUnit.Case

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions

  alias Membrane.RawVideo
  alias Membrane.Testing
  alias Membrane.VideoCompositor.MultipleInputs, as: MultiVideoCompositor
  alias Membrane.VideoCompositor.Test.Mock.FrameComposer.MultipleInput, as: MockFrameComposer

  @no_video %RawVideo{
    width: 0,
    height: 0,
    framerate: {0, 1},
    pixel_format: :I420,
    aligned: false
  }

  test "abc" do
    children = [
      source_0: %Testing.Source{output: ["a0", "a1", "a2"], caps: @no_video},
      source_1: %Testing.Source{output: ["b0", "b1", "b2"], caps: @no_video},
      source_2: %Testing.Source{output: ["c0", "c1", "c2"], caps: @no_video},
      composer: %MultiVideoCompositor{
        implementation: MockFrameComposer,
        caps: @no_video
      },
      sink: Testing.Sink
    ]

    links = [
      link(:source_0) |> to(:composer),
      link(:source_1) |> to(:composer),
      link(:source_2) |> to(:composer),
      link(:composer) |> to(:sink)
    ]

    {:ok, pid} = Testing.Pipeline.start_link(children: children, links: links)

    assert_pipeline_playback_changed(pid, _, :playing)

    expected = [
      "a0b0c0",
      "a1b1c1",
      "a2b2c2"
    ]

    Enum.each(expected, fn exp ->
      assert_sink_buffer(pid, :sink, %Membrane.Buffer{payload: payload})
      assert(payload == exp)
    end)

    Testing.Pipeline.terminate(pid, blocking?: true)
  end
end
