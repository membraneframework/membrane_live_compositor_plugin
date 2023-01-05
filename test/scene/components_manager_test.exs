defmodule Membrane.VideoCompositor.Test.Scene.ComponentsManager do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager
  alias Membrane.VideoCompositor.Test.Support.Scene.Mocks

  test "Single mock component update" do
    target_state = %{}

    manager = %Manager{}

    assert {manager, target_state} =
             Manager.register(manager, target_state, Mocks.Stateless.Add, :add)

    assert %{count: 0} = Map.get(target_state, :add)

    set_amount = 20

    assert {manager, target_state} =
             Manager.register(manager, target_state, Mocks.Stateful.Set, :set, set_amount)

    assert 0 = Map.get(target_state, :set)

    components = [set: Mocks.Stateful.Set, add: Mocks.Stateless.Add]

    assert {target_state, components} = Manager.update(target_state, components, manager, nil)

    assert components == [set: Mocks.Stateful.Set, add: Mocks.Stateless.Add]

    assert %{set: 20, add: %{count: 1}} = target_state

    assert_raise RuntimeError, "Error msg set", fn ->
      Manager.update(target_state, components, manager, :error)
    end

    assert {_target_state, components} = Manager.update(target_state, components, manager, :done)

    assert Enum.empty?(components)
  end
end
