defmodule Membrane.LiveCompositor.EventHandler do
  @moduledoc false

  use WebSockex

  require Membrane.Logger
  require Membrane.Pad

  alias Membrane.Pad

  @spec start_link({:inet.port_number(), pid()}) :: {:ok, pid} | {:error, term}
  def start_link({port, parent_pid}) do
    WebSockex.start_link("ws://127.0.0.1:#{port}/ws", __MODULE__, %{parent_pid: parent_pid})
  end

  @impl true
  def handle_connect(_conn, state) do
    send(state.parent_pid, :websocket_connected)
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    {:ok, msg} = Jason.decode(msg)
    send(state.parent_pid, {:websocket_message, msg_to_event(msg)})
    {:ok, state}
  end

  @impl true
  def handle_frame({type, msg}, state) do
    Membrane.Logger.debug(
      "Unknown WebSocket message - Type: #{inspect(type)} -- Message: #{inspect(msg)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_cast(_message, state) do
    {:ok, state}
  end

  @spec msg_to_event(any()) :: any()
  defp msg_to_event(msg) do
    case msg do
      %{"type" => "VIDEO_INPUT_DELIVERED", "input_id" => input_id} ->
        {:input_delivered, Pad.ref(:video_input, input_id)}

      %{"type" => "VIDEO_INPUT_PLAYING", "input_id" => input_id} ->
        {:input_playing, Pad.ref(:video_input, input_id)}

      %{"type" => "VIDEO_INPUT_EOS", "input_id" => input_id} ->
        {:input_eos, Pad.ref(:video_input, input_id)}

      %{"type" => "AUDIO_INPUT_DELIVERED", "input_id" => input_id} ->
        {:input_delivered, Pad.ref(:audio_input, input_id)}

      %{"type" => "AUDIO_INPUT_PLAYING", "input_id" => input_id} ->
        {:input_playing, Pad.ref(:audio_input, input_id)}

      %{"type" => "AUDIO_INPUT_EOS", "input_id" => input_id} ->
        {:input_eos, Pad.ref(:audio_input, input_id)}

      msg ->
        msg
    end
  end
end
