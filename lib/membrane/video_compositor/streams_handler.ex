defmodule Membrane.LiveCompositor.StreamsHandler do
  @moduledoc false

  alias Membrane.LiveCompositor
  alias Membrane.LiveCompositor.{OutputOptions, Request, State}

  @spec register_input_stream(
          LiveCompositor.input_id(),
          :inet.port_number() | LiveCompositor.port_range(),
          State.t()
        ) ::
          {:ok, :inet.port_number()} | {:error, any()}
  def register_input_stream(input_id, port, state) do
    case Request.register_input_stream(input_id, port, state.lc_port) do
      {:ok, response} -> {:ok, response.body["port"]}
      {:error_response_code, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end

  @spec register_output_stream(OutputOptions.t(), State.t()) ::
          :ok | {:error, any()}
  def register_output_stream(output_opt, state) do
    result =
      Request.register_output_stream(
        output_opt,
        state.lc_port
      )

    case result do
      {:ok, _response} -> :ok
      {:error_response_code, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end
end
