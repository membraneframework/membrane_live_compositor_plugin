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
    def handle_init(_options \\ nil, _context \\ nil) do
      %{count: 0}
    end

    @impl true
    def inject_into_target_state(target, state, id) do
      Map.put(target, id, 0) |> Map.put(:state, state)
    end

    @impl true
    def handle_update(_target_state, _state, _id, :error) do
      raise "Error msg"
    end

    @impl true
    def handle_update(target_state, _state, _id, :done) do
      {:done, target_state}
    end

    @impl true
    def handle_update(target_state, _state, id, time) do
      state = Map.get(target_state, :state) |> Map.update!(:count, &(&1 + 1))

      target_state =
        Map.put(target_state, id, time)
        |> Map.put(:state, state)

      {:ongoing, target_state}
    end
  end

  test "Single mock component update" do
    target_state = %{}

    assert not Mock.Add.use_caching?()

    assert %{count: 0} = state = Mock.Add.handle_init()

    assert %{target: 0} =
             target_state = Mock.Add.inject_into_target_state(target_state, state, :target)

    assert {:ongoing, target_state} = Mock.Add.handle_update(target_state, state, :target, 6)

    assert %{target: 6, state: %{count: 1}} = target_state

    assert {:ongoing, target_state} = Mock.Add.handle_update(target_state, state, :target, 3)

    assert %{target: 3, state: %{count: 2}} = target_state

    assert {:ongoing, target_state} = Mock.Add.handle_update(target_state, state, :target, 1)

    assert %{target: 1, state: %{count: 3}} = target_state

    assert {:done, target_state} = Mock.Add.handle_update(target_state, state, :target, :done)

    assert_raise RuntimeError, "Error msg", fn ->
      Mock.Add.handle_update(target_state, state, :target, :error)
    end
  end
end
