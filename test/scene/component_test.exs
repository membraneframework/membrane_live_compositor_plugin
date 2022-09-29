defmodule Membrane.VideoCompositor.Test.Scene.Component do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Scene.Component

  defmodule Mock.Add do
    @behaviour Component

    @impl true
    def use_caching?() do
      false
    end

    @impl true
    def handle_init(_options \\ nil) do
      {:ok, %{count: 0}}
    end

    @impl true
    def inject_into_target_state(target, state) do
      {:ok, Map.put(target, :target, 0) |> Map.put(:state, state)}
    end

    @impl true
    def handle_update(_target_state, _state, :error) do
      {:error, "Error msg"}
    end

    @impl true
    def handle_update(target_state, _state, :done) do
      {:ok, {:done, target_state}}
    end

    @impl true
    def handle_update(target_state, _state, time) do
      state = Map.get(target_state, :state) |> Map.update!(:count, &(&1 + 1))

      target_state =
        Map.put(target_state, :target, time)
        |> Map.put(:state, state)

      {:ok, {:ongoing, target_state}}
    end
  end

  test "Single mock component update" do
    target_state = %{}

    assert not Mock.Add.use_caching?()

    assert {:ok, %{count: 0} = state} = Mock.Add.handle_init()

    assert {:ok, %{target: 0} = target_state} =
             Mock.Add.inject_into_target_state(target_state, state)

    assert {:ok, {:ongoing, target_state}} = Mock.Add.handle_update(target_state, state, 6)
    assert %{target: 6, state: %{count: 1}} = target_state

    assert {:ok, {:ongoing, target_state}} = Mock.Add.handle_update(target_state, state, 3)
    assert %{target: 3, state: %{count: 2}} = target_state

    assert {:ok, {:ongoing, target_state}} = Mock.Add.handle_update(target_state, state, 1)
    assert %{target: 1, state: %{count: 3}} = target_state

    assert {:ok, {:done, target_state}} = Mock.Add.handle_update(target_state, state, :done)

    assert {:error, "Error msg"} = Mock.Add.handle_update(target_state, state, :error)
  end
end
