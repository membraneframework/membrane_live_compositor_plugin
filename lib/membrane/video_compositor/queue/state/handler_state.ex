defmodule Membrane.VideoCompositor.Queue.State.HandlerState do
  @moduledoc false
  # Keeps state of VC handler.

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.{CompositorCoreFormat, Handler, Scene}
  alias Membrane.VideoCompositor.Handler.InputProperties
  alias Membrane.VideoCompositor.Queue.State

  @enforce_keys [:handler_module, :handler_state]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          handler_module: Handler.t(),
          handler_state: Handler.state()
        }

  @spec new(VideoCompositor.init_options()) :: t()
  def new(init_options) do
    %__MODULE__{
      handler_module: init_options.handler,
      handler_state: init_options.handler.handle_init(init_options)
    }
  end

  @spec check_callbacks(State.t(), State.t()) :: State.t()
  def check_callbacks(new_state, previous_state) do
    new_state
    |> maybe_handle_inputs_change(previous_state)
    |> handle_infos()
  end

  @spec maybe_handle_inputs_change(State.t(), State.t()) :: State.t()
  defp maybe_handle_inputs_change(new_state, previous_state) do
    if previous_state.output_format != new_state.output_format do
      handle_inputs_change(new_state, previous_state)
    else
      new_state
    end
  end

  @spec handle_infos(State.t()) :: State.t()
  defp handle_infos(new_state) do
    new_state.user_messages
    |> Enum.reduce(new_state, fn msg, state -> do_handle_info(msg, state) end)
  end

  @spec handle_inputs_change(State.t(), State.t()) :: State.t()
  defp handle_inputs_change(new_state, previous_state) do
    %__MODULE__{handler_module: handler, handler_state: handler_state} = new_state.handler

    inputs = get_inputs(new_state)
    ctx = get_callback_context(previous_state)

    {scene, handler_state} =
      case handler.handle_inputs_change(inputs, ctx, handler_state) do
        {scene = %Scene{}, state} ->
          {scene, state}

        other ->
          raise """
          Improper return from handler #{inspect(handler)} for `handle_inputs_change` implementation.
          Improper return: #{inspect(other)}
          for arguments:
          inputs: #{inspect(inputs)}
          context: #{inspect(ctx)}
          handler_state: #{inspect(handler_state)}

          Check callbacks API specification in #{inspect(Membrane.VideoCompositor.Handler)}
          """
      end

    %State{
      new_state
      | handler: %__MODULE__{new_state.handler | handler_state: handler_state},
        scene: scene
    }
  end

  @spec do_handle_info(any(), State.t()) :: State.t()
  defp do_handle_info(msg, new_state) do
    %__MODULE__{handler_module: handler, handler_state: handler_state} = new_state.handler
    ctx = get_callback_context(new_state)

    {scene, handler_state} =
      case handler.do_handle_info(msg, ctx, handler_state) do
        {scene = %Scene{}, state} ->
          {scene, state}

        other ->
          raise """
          Improper return from handler #{inspect(handler)} for `handle_info` implementation.
          Improper return: #{inspect(other)}
          for arguments:
          msg: #{inspect(msg)}
          context: #{inspect(ctx)}
          handler_state: #{inspect(handler_state)}

          Check callbacks API specification in #{inspect(Membrane.VideoCompositor.Handler)}
          """
      end

    %State{
      new_state
      | handler: %__MODULE__{handler_module: handler, handler_state: handler_state},
        scene: scene
    }
  end

  @spec get_inputs(State.t()) :: Handler.inputs()
  defp get_inputs(%State{
         output_format: %CompositorCoreFormat{pad_formats: pad_formats},
         pads_states: pads_states
       }) do
    pad_formats
    |> Enum.map(fn {pad, pad_format} ->
      {pad,
       %InputProperties{
         stream_format: pad_format,
         metadata: Bunch.Struct.get_in(pads_states, [pad, :metadata])
       }}
    end)
    |> Enum.into(%{})
  end

  @spec get_callback_context(State.t()) :: Handler.context()
  defp get_callback_context(state) do
    %{
      scene: state.scene,
      inputs: get_inputs(state),
      next_frame_pts: state.next_buffer_pts,
      scenes_queue: []
    }
  end
end
