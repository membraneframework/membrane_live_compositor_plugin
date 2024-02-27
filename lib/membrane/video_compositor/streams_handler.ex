defmodule Membrane.LiveCompositor.StreamsHandler do
  @moduledoc false

  alias Membrane.LiveCompositor.{OutputOptions, Request, State}

  @spec register_input_stream(map(), State.t()) ::
          {:ok, :inet.port_number()} | {:error, any()}
  def register_input_stream(input_pad_opts, state) do
    case Request.register_input_stream(input_pad_opts, state.lc_port) do
      {:ok, response} -> {:ok, response.body["port"]}
      {:error_response_code, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end

  @spec register_output_stream(OutputOptions.t(), State.t()) ::
          {:ok, :inet.port_number()} | {:error, any()}
  def register_output_stream(output_opt, state) do
    result = Request.register_output_stream(output_opt, state.lc_port)

    case result do
      {:ok, response} -> {:ok, response.body["port"]}
      {:error_response_code, err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end
end
