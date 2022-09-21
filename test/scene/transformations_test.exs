defmodule Membrane.VideoCompositor.Test.Scene.Transformations do
  use ExUnit.Case, async: true

  alias Membrane.VideoCompositor.Scene.Transformation

  defmodule Mock.Add do
    @behaviour Transformation

    @impl true
    def handle_update(_target_state, _state, :error) do
      {:error, "Error msg"}
    end

    @impl true
    def handle_update(target_state, state, :done) do
      {:done, {target_state, state}}
    end

    @impl true
    def handle_update(target_state, state, time) do
      target_state = Map.put(target_state, :target, time)
      state = Map.update!(state, :count, &(&1 + 1))
      {:ongoing, {target_state, state}}
    end
  end

  test "Single mock scene element" do
    trans = %Transformation{
      state: %{count: 0},
      module: Mock.Add
    }

    target_state = %{target: 0}

    assert {:ongoing, {target_state, trans}} = Transformation.update(target_state, trans, 6)
    assert {%{target: 6}, %Transformation{state: %{count: 1}}} = {target_state, trans}

    assert {:ongoing, {target_state, trans}} = Transformation.update(target_state, trans, 3)
    assert {%{target: 3}, %Transformation{state: %{count: 2}}} = {target_state, trans}

    assert {:ongoing, {target_state, trans}} = Transformation.update(target_state, trans, 1)
    assert {%{target: 1}, %Transformation{state: %{count: 3}}} = {target_state, trans}

    assert {:done, {target_state, trans}} = Transformation.update(target_state, trans, :done)

    assert {:error, _error} = Transformation.update(target_state, trans, :error)
  end

  test "Multiple mock scenes elements" do
    transformations_states = [
      first: %Transformation{
        state: %{count: 0},
        module: Mock.Add
      },
      second: %Transformation{
        state: %{count: 3},
        module: Mock.Add
      }
    ]

    target_state = %{target: 0}

    assert {:ongoing, {target_state, transformations_states}} =
             Transformation.update_all(target_state, transformations_states, 6)

    assert %{target: 6} = target_state
    assert %Transformation{state: %{count: 1}} = Keyword.get(transformations_states, :first)
    assert %Transformation{state: %{count: 4}} = Keyword.get(transformations_states, :second)
    assert 2 = length(transformations_states)

    assert {:error, "Error msg"} =
             Transformation.update_all(target_state, transformations_states, :error)

    assert {:ongoing, {%{target: 6}, []}} =
             Transformation.update_all(target_state, transformations_states, :done)
  end
end
