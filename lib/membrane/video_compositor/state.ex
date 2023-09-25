defmodule Membrane.VideoCompositor.State do
  @moduledoc false

  alias Membrane.VideoCompositor.{Handler, Scene}

  defstruct [:inputs, :outputs, :handler_state, :handler]

  @type t :: %__MODULE__{
          inputs: list(Handler.input_context()),
          outputs: list(Handler.output_context()),
          handler_state: Handler.state(),
          handler: Handler.t()
        }

  @spec handler_context(t()) :: Handler.Context.t()
  def handler_context(vc_state) do
    %Handler.Context{
      inputs: vc_state.inputs,
      outputs: vc_state.outputs
    }
  end

  @spec call_handle_pads_change(t()) :: {:update_scene, Scene.t(), t()} | t()
  def call_handle_pads_change(state) do
    handler_ctx = handler_context(state)

    case state.handler.handle_pads_change(handler_ctx, state.handler_state) do
      {:update_scene, new_scene, handler_state} ->
        {:update_scene, new_scene, %__MODULE__{state | handler_state: handler_state}}

      handler_state ->
        %__MODULE__{
          state
          | handler_state: handler_state
        }
    end
  end
end
