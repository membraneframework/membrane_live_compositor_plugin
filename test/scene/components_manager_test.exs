defmodule Membrane.VideoCompositor.Test.Scene.ComponentsManager do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Scene.Component
  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager

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

  test "Single mock component update" do
    target_state = %{}

    manager = %{
      cached: %{}
    }

    assert {:ok, {manager, target_state}} =
             Manager.register(manager, target_state, Mock.Stateless.Add)

    assert %{count: 0} = Map.get(target_state, Mock.Stateless.Add)

    set_amount = 20

    assert {:ok, {manager, target_state}} =
             Manager.register(manager, target_state, Mock.Stateful.Set, set_amount)

    assert 0 = Map.get(target_state, Mock.Stateful.Set)

    components = [set: Mock.Stateful.Set, add: Mock.Stateless.Add]

    assert {:ok, {target_state, components}} =
             Manager.update(target_state, components, manager, nil)

    assert components == [set: Mock.Stateful.Set, add: Mock.Stateless.Add]

    assert %{Mock.Stateful.Set => 20, Mock.Stateless.Add => %{count: 1}} = target_state

    assert {:error, "Error msg set"} = Manager.update(target_state, components, manager, :error)

    assert {:ok, {_target_state, components}} =
             Manager.update(target_state, components, manager, :done)

    assert Enum.empty?(components)
  end
end
