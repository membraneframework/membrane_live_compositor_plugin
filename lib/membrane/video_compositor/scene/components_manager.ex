defmodule Membrane.VideoCompositor.Scene.ComponentsManager do
  @moduledoc """
  Manages components' global states
  """

  alias Membrane.VideoCompositor.Scene.Component

  @type state_t() :: any()
  @type target_state_t() :: any()
  @type error_t() :: any()

  @type t() :: %{}

  defp init_or_get_module(manager, module, options) do
    if module.use_caching? and
         Map.has_key?(manager.cached, module) do
      {:ok, Map.get(manager.cached, module)}
    else
      module.handle_init(options)
    end
  end

  defp update_cache(manager, module, state) do
    {:ok,
     if module.use_caching?() do
       %{manager | cached: Map.put_new(manager.cached, module, state)}
     else
       manager
     end}
  end

  @spec register(t(), target_state_t(), module(), any()) ::
          {:ok, {t(), target_state_t()}} | {:error, error_t()}
  def register(manager, target_state, module, options \\ nil) do
    with {:ok, state} <- init_or_get_module(manager, module, options),
         {:ok, manager} <- update_cache(manager, module, state),
         {:ok, target_state} <- module.inject_into_target_state(target_state, state) do
      {:ok, {manager, target_state}}
    else
      {:error, error} -> {:error, error}
    end
  end

  @spec get(t(), module()) :: {:ok, state_t()} | {:error, error_t()}
  def get(manager, component_module) do
    if component_module.use_caching? do
      cached = Map.get(manager, :cached)

      if Map.has_key?(cached, component_module) do
        {:ok, Map.get(cached, component_module)}
      else
        {:error, {"Component module has not been registered", component_module}}
      end
    else
      {:ok, nil}
    end
  end

  defp update_module(
         manager,
         target_state,
         components_modules,
         component_id,
         component_module,
         time
       ) do
    with {:ok, component_state} <- get(manager, component_module),
         {:ok, {component_status, target_state}} <-
           component_module.handle_update(target_state, component_state, time) do
      case component_status do
        :ongoing ->
          {:ok, {target_state, Keyword.put(components_modules, component_id, component_module)}}

        :done ->
          {:ok, {target_state, components_modules}}
      end
    else
      {:error, error} -> {:error, error}
    end
  end

  @spec update(target_state_t, keyword(Component), t(), Component.time_t()) ::
          {:ok, {target_state_t(), keyword(Component)}} | {:error, error_t()}
  def update(target_state, components_modules, manager, time) do
    {status, return} =
      Enum.reduce_while(components_modules, {:ok, {target_state, []}}, fn
        {id, component_module}, {:ok, {target_state, components_modules}} ->
          case update_module(
                 manager,
                 target_state,
                 components_modules,
                 id,
                 component_module,
                 time
               ) do
            {:ok, {target_state, components_modules}} ->
              {:cont, {:ok, {target_state, components_modules}}}

            {:error, error} ->
              {:halt, {:error, error}}
          end
      end)

    case {status, return} do
      {:ok, {target_state, components_modules}} ->
        {:ok, {target_state, Enum.reverse(components_modules)}}

      {:error, error} ->
        {:error, error}
    end
  end
end
