defmodule Membrane.VideoCompositor.Test.Scene.Initialization do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Component

  defmodule Mock.Stateful.Set do
    @behaviour Component

    @impl true
    def use_caching?() do
      true
    end

    @impl true
    def handle_init(amount) do
      {:ok, amount}
    end

    @impl true
    def inject_into_target_state(target, _state) do
      {:ok, Map.put(target, __MODULE__, 0)}
    end

    @impl true
    def handle_update(_target_state, _state, :error) do
      {:error, "Error msg set"}
    end

    @impl true
    def handle_update(target_state, _state, :done) do
      {:ok, {:done, target_state}}
    end

    @impl true
    def handle_update(target_state, amount, _time) do
      target_state = Map.put(target_state, __MODULE__, amount)
      {:ok, {:ongoing, target_state}}
    end
  end

  defmodule Mock.Stateless.Add do
    @behaviour Component

    @impl true
    def use_caching?() do
      false
    end

    @impl true
    def handle_init(_options \\ nil) do
      {:ok, nil}
    end

    @impl true
    def inject_into_target_state(target, nil = _state) do
      {:ok, Map.put(target, __MODULE__, %{count: 0})}
    end

    @impl true
    def handle_update(_target_state, nil = _state, :error) do
      {:error, "Error msg add"}
    end

    @impl true
    def handle_update(target_state, nil = _state, :done) do
      {:ok, {:done, target_state}}
    end

    @impl true
    def handle_update(target_state, nil = _state, _time) do
      target_state =
        Map.update!(
          target_state,
          __MODULE__,
          fn state -> Map.update!(state, :count, &(&1 + 1)) end
        )

      {:ok, {:ongoing, target_state}}
    end
  end

  describe "Scene transformations" do
    test "by the static initialization" do
      scene_description = [
        videos: %{
          0 => [
            position: %Position{
              x: 0,
              y: 0
            },
            setter: {Mock.Stateful.Set, 20},
            adder: Mock.Stateless.Add
          ],
          1 => [
            position: %Position{
              x: 0,
              y: 1080
            }
          ]
        },
        setter: {Mock.Stateful.Set, 20},
        adder: Mock.Stateless.Add
      ]

      manager = %{cached: %{}}

      assert {:ok, {_scene, _manager}} = Scene.init(scene_description, manager)
    end
  end
end
