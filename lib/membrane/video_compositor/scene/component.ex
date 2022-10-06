defmodule Membrane.VideoCompositor.Scene.Component do
  @moduledoc """
  Components represent transformations on the target states.
  Have "global" states (`handle_init/1`) (which can be shared between all instances, if `use_caching?/0`)
  and can inject local state into the target's state (`inject_into_target_state/3`).
  Can use NIFs
  """

  @type target_state_t() :: any()
  @type options_t() :: any()
  @type state_t() :: any()
  @type error_t() :: any()
  @type context_t() :: any()

  @doc """
  If module has some global state which is shared between all its instances (compiled shader, for example),
  state from `handle_init/2` will be cached.
  """
  @callback use_caching?() :: boolean()

  @doc """
  If module `use_caching?/0`, result will be stored and shared between all initializations.
  Otherwise, it will be called during all registrations.
  """
  @callback handle_init(options_t(), context :: any()) ::
              {:ok, state_t()} | {:error, error_t()}

  @doc """
  Component can ensure target state contains some common properties (position, mesh, etc.)
  or inject own, unique state to the target (percent of completeness, etc.)
  """
  @callback inject_into_target_state(target_state_t(), state_t(), id :: atom()) ::
              {:ok, target_state_t()} | {:error, error_t()}

  @callback handle_update(target_state_t(), state_t(), id :: atom(), context :: any()) ::
              {:ok, {:done | :ongoing, target_state_t()}} | {:error, error_t()}
end
