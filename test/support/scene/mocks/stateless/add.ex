defmodule Membrane.VideoCompositor.Test.Support.Scene.Mocks.Stateless.Add do
  @moduledoc false
  @behaviour Membrane.VideoCompositor.Scene.Component

  @impl true
  def use_caching?() do
    false
  end

  @impl true
  def handle_init(_options \\ nil, _context \\ nil) do
    {:ok, nil}
  end

  @impl true
  def inject_into_target_state(target, nil = _state, id) do
    {:ok, Map.put(target, id, %{count: 0})}
  end

  @impl true
  def handle_update(_target_state, nil = _state, _id, :error) do
    {:error, "Error msg add"}
  end

  @impl true
  def handle_update(target_state, nil = _state, _id, :done) do
    {:ok, {:done, target_state}}
  end

  @impl true
  def handle_update(target_state, nil = _state, id, _context) do
    target_state =
      Map.update!(
        target_state,
        id,
        fn state -> Map.update!(state, :count, &(&1 + 1)) end
      )

    {:ok, {:ongoing, target_state}}
  end
end
