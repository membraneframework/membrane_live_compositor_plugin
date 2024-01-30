defmodule Membrane.LiveCompositor.StreamsHandler do
  @moduledoc false

  alias Membrane.LiveCompositor
  alias Membrane.LiveCompositor.{OutputOptions, Request, State}

  @spec register_input_stream(LiveCompositor.input_id(), State.t()) ::
          {:ok, :inet.port_number()} | :error
  def register_input_stream(input_id, state) do
    try_register = fn input_port ->
      Request.register_input_stream(input_id, input_port, state.lc_port)
    end

    pick_port(try_register, state)
  end

  @spec register_output_stream(OutputOptions.t(), Membrane.LiveCompositor.State.t()) ::
          {:ok, :inet.port_number()} | :error
  def register_output_stream(output_opt, state) do
    try_register = fn output_port ->
      Request.register_output_stream(
        output_opt,
        output_port,
        state.lc_port
      )
    end

    pick_port(try_register, state)
  end

  @spec pick_port((:inet.port_number() -> Request.request_result()), State.t()) ::
          {:ok, :inet.port_number()} | :error
  defp pick_port(try_register, state) do
    {port_lower_bound, port_upper_bound} = state.port_range
    used_ports = state |> State.used_ports() |> MapSet.new()

    port_lower_bound..port_upper_bound
    |> Enum.shuffle()
    |> Enum.reduce_while(:error, fn port, _acc -> try_port(try_register, port, used_ports) end)
  end

  @spec try_port(
          (:inet.port_number() -> Request.request_result()),
          :inet.port_number(),
          MapSet.t()
        ) ::
          {:halt, {:ok, :inet.port_number()}} | {:cont, :error}
  defp try_port(try_register, port, used_ports) do
    # FFmpeg reserves additional ports for RTP streams.
    if [port - 1, port, port] |> Enum.any?(fn port -> MapSet.member?(used_ports, port) end) do
      {:cont, :error}
    else
      case try_register.(port) do
        {:ok, _resp} ->
          {:halt, {:ok, port}}

        {:error_response_code, _resp} ->
          {:cont, :error}

        _other ->
          raise "Register input failed"
      end
    end
  end
end
