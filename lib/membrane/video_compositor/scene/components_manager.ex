defmodule Membrane.VideoCompositor.Scene.ComponentsManager do
  @moduledoc """
  Manages components' global states
  """

  alias Membrane.VideoCompositor.Scene.Component
  alias Membrane.VideoCompositor.Scene.ElementDescription

  @type state_t() :: any()
  @type target_state_t() :: any()
  @type error_t() :: any()

  @type t() :: %{
          cached: %{required(id :: atom()) => state_t()}
        }
  defstruct cached: %{}

  defp init_or_get_module(manager, module, options) do
    if module.use_caching? and
         Map.has_key?(manager.cached, module) do
      Map.get(manager.cached, module)
    else
      module.handle_init(options)
    end
  end

  defp update_cache(manager, module, state) do
    if module.use_caching?() do
      %{manager | cached: Map.put_new(manager.cached, module, state)}
    else
      manager
    end
  end

  @spec register(t(), target_state_t(), module(), id :: atom(), any()) ::
          {t(), target_state_t()}
  def register(manager, target_state, module, id, options \\ nil) when is_atom(module) do
    state = init_or_get_module(manager, module, options)
    manager = update_cache(manager, module, state)
    target_state = module.inject_into_target_state(target_state, state, id)
    {manager, target_state}
  end

  @spec register_element(manager :: t, ElementDescription.t()) ::
          {manager :: t, state :: any}
  def register_element(manager, element) do
    Enum.reduce(
      element.components,
      {manager, element.state},
      fn {id, {module, options}}, {manager, state} ->
        register(manager, state, module, id, options)
      end
    )
  end

  @spec get(t(), module()) :: state_t()
  def get(manager, component_module) do
    if component_module.use_caching? do
      cached = Map.get(manager, :cached)

      if Map.has_key?(cached, component_module) do
        Map.get(cached, component_module)
      else
        raise ArgumentError,
          message: {"Component module has not been registered", component_module}
      end
    else
      nil
    end
  end

  defp update_module(
         manager,
         target_state,
         components_modules,
         component_id,
         component_module,
         context
       ) do
    component_state = get(manager, component_module)

    {component_status, target_state} =
      component_module.handle_update(target_state, component_state, component_id, context)

    case component_status do
      :ongoing ->
        {target_state, Keyword.put(components_modules, component_id, component_module)}

      :done ->
        {target_state, components_modules}
    end
  end

  @spec update(target_state_t, keyword(Component), t(), Component.context_t()) ::
          {target_state_t(), keyword(Component)}
  def update(target_state, components_modules, manager, context) do
    {target_state, components_modules} =
      Enum.reduce(components_modules, {target_state, []}, fn
        {id, component_module}, {target_state, components_modules} ->
          update_module(
            manager,
            target_state,
            components_modules,
            id,
            component_module,
            context
          )
      end)

    {target_state, Enum.reverse(components_modules)}
  end
end
