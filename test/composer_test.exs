defmodule Membrane.VideoCompositor.Test.Composer.ThreeSame do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Testing
  alias Membrane.VideoCompositor.Test.Support.Pipeline.Mock

  setup do
    {:ok, pid} =
      Mock.start_multi_input_pipeline([
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

defmodule Membrane.VideoCompositor.Test.Composer.DifferentSizeBuffers do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Testing
  alias Membrane.VideoCompositor.Test.Support.Pipeline.Mock

  setup do
    {:ok, pid} =
      Mock.start_multi_input_pipeline([
        ["a0"],
        ["b0", "b1"],
        ["c0", "c1", "c2"],
        ["d0", "d1", "d2", "d3"],
        ["e0", "e1", "e2"]
      ])

    %{pipeline: pid}
  end

  describe "Compose five sources with the different amount of buffers" do
    test "and buffers are composed correctly", %{pipeline: pid} do
      assert_pipeline_playback_changed(pid, _from, :playing)

      expected = [
        "a0b0c0d0e0",
        "b1c1d1e1",
        "c2d2e2",
        "d3"
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
