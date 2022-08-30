defmodule Membrane.VideoCompositor.Test.MultiInputComposerTest.Utility do
  import Membrane.ParentSpec

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

  @spec start_multi_input_pipeline([[String.t()]]) :: {:ok, pid()}
  def start_multi_input_pipeline(inputs) do
    source_children =
      for {input, i} <- Enum.with_index(inputs),
          do: {String.to_atom("source_#{i}"), %Testing.Source{output: input, caps: @no_video}}

    source_links =
      source_children
      |> Enum.map(fn {source_id, _element} -> link(source_id) |> to(:composer) end)

    children =
      source_children ++
        [
          composer: %MultiVideoCompositor{
            implementation: MockFrameComposer,
            caps: @no_video
          },
          sink: Testing.Sink
        ]

    links =
      source_links ++
        [
          link(:composer) |> to(:sink)
        ]

    Testing.Pipeline.start_link(children: children, links: links)
  end
end

defmodule MultiInputComposerTest.ThreeSame do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Testing
  alias Membrane.VideoCompositor.Test.MultiInputComposerTest.Utility

  setup do
    {:ok, pid} =
      Utility.start_multi_input_pipeline([
        ["a0", "a1", "a2"],
        ["b0", "b1", "b2"],
        ["c0", "c1", "c2"]
      ])

    %{pipeline: pid}
  end

  describe "Compose three sources with the same amount of buffers" do
    test "and buffers are composed correctly", %{pipeline: pid} do
      assert_pipeline_playback_changed(pid, _from, :playing)

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

    test "and pipeline sent eos", %{pipeline: pid} do
      assert_pipeline_playback_changed(pid, _from, :playing)

      assert_end_of_stream(pid, :sink)

      Testing.Pipeline.terminate(pid, blocking?: true)
    end
  end
end
