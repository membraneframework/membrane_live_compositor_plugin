defmodule Membrane.VideoCompositor.Test.Scene.Video do
  use ExUnit.Case, async: true

  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene.Transformation
  alias Membrane.VideoCompositor.Scene.Video

  defmodule Mock.Position.SetTime do
    @behaviour Transformation

    @impl true
    def handle_update(_target_state, _state, :error) do
      {:error, "First error msg"}
    end

    @impl true
    def handle_update(target_state, state, :done) do
      {:done, {target_state, state}}
    end

    @impl true
    def handle_update(target_state, state, time) do
      target_state = Map.put(target_state, :position, %Position{x: time, y: time})
      {:ongoing, {target_state, state}}
    end
  end

  defmodule Mock.Position.AddOne do
    @behaviour Transformation

    @impl true
    def handle_update(_target_state, _state, :error) do
      {:error, "Second error msg"}
    end

    @impl true
    def handle_update(target_state, state, :done) do
      {:done, {target_state, state}}
    end

    @impl true
    def handle_update(target_state, state, _time) do
      target_state =
        Map.update!(target_state, :position, fn pos -> %Position{x: pos.x + 1, y: pos.y + 1} end)

      {:ongoing, {target_state, state}}
    end
  end

  test "Single mock scene element" do
    video = %Video{
      position: %Position{
        x: 0,
        y: 0
      },
      transformations: [
        set: %Transformation{
          module: Mock.Position.SetTime,
          state: %{}
        },
        add: %Transformation{
          module: Mock.Position.AddOne,
          state: %{}
        }
      ]
    }

    assert {:ok, video} = Video.update(video, 10)
    assert %Video{position: %Position{x: 11, y: 11}} = video

    assert {:error, "First error msg"} = Video.update(video, :error)
    assert %Video{position: %Position{x: 11, y: 11}} = video
    assert 2 = length(video.transformations)

    assert {:ok, video} = Video.update(video, :done)
    assert %Video{position: %Position{x: 11, y: 11}} = video
    assert Enum.empty?(video.transformations)
  end
end
