defmodule Membrane.VideoCompositor.Test.Support.Scene.Mocks.Stateful.Set do
  @moduledoc false
  @behaviour Membrane.VideoCompositor.Scene.Component

  @impl true
  def use_caching?() do
    true
  end

  @impl true
  def handle_init(amount, _context \\ nil) do
    amount
  end

  @impl true
  def inject_into_target_state(target, _state, id) do
    Map.put(target, id, 0)
  end

  @impl true
  def handle_update(_target_state, _state, _id, :error) do
    raise "Error msg set"
  end

  @impl true
  def handle_update(target_state, _state, _id, :done) do
    {:done, target_state}
  end

  @impl true
  def handle_update(target_state, amount, id, _time) do
    target_state = Map.put(target_state, id, amount)

    {:ongoing, target_state}
  end
end
