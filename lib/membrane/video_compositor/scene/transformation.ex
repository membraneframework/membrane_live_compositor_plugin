defmodule Membrane.VideoCompositor.Scene.Transformation do
  @moduledoc """
  Transforming a target state using time parameter. Can update one or multiple transformations at once.
  """

  @type target_state_t() :: any()
  @type state_t() :: any()
  @type error_t() :: any()

  @type t :: %__MODULE__{
          state: state_t(),
          module: module()
        }

  @enforce_keys [:state, :module]
  defstruct state: nil, module: nil

  @callback handle_update(
              target_state :: target_state_t(),
              state :: state_t(),
              time :: number()
            ) ::
              {:ongoing, {target_state_t(), state_t()}}
              | {:done, {target_state_t(), state_t()}}
              | {:error, error_t()}

  @spec update(target_state_t(), t(), number()) ::
          {:ongoing | :done, {target_state_t(), t()}}
          | {:error, error_t()}
  def update(target_state, transformation_state, time) do
    case transformation_state.module.handle_update(target_state, transformation_state.state, time) do
      {:error, error} ->
        {:error, error}

      {status, {target_state, transformation}} ->
        {status, {target_state, %__MODULE__{transformation_state | state: transformation}}}
    end
  end

  @doc """
  Apply all transformations on the given state, in the order.
  Any transformation returning `:done` will be removed from the list.
  If any transformation returns `:error`,
  whole transformations chain will be halted and `{:error, error}` will be returned immediately.
  """
  @spec update_all(target_state_t(), keyword(t()), number()) ::
          {:ok, {target_state_t(), keyword(t())}}
          | {:error, error_t()}
  def update_all(target_state, transformations_states, time) do
    states =
      Enum.reduce_while(transformations_states, {target_state, []}, fn
        {id, transformation_state}, {target_state, transformations_states} ->
          case update(target_state, transformation_state, time) do
            {:ongoing, {target_state, transformation_state}} ->
              {:cont,
               {target_state, Keyword.put(transformations_states, id, transformation_state)}}

            {:done, {target_state, _transformation}} ->
              {:cont, {target_state, transformations_states}}

            {:error, error} ->
              {:halt, {:error, error}}
          end
      end)

    case states do
      {:error, error} ->
        {:error, error}

      {target_state, transformations_states} ->
        {:ok, {target_state, Enum.reverse(transformations_states)}}
    end
  end
end
