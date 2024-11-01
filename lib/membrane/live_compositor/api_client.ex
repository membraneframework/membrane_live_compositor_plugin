defmodule Membrane.LiveCompositor.ApiClient do
  @moduledoc false

  require Membrane.Logger

  @type http_method :: :post | :get
  @type request :: {http_method(), path :: String.t(), body :: any()}

  @local_host_url "127.0.0.1"
  @type request_result ::
          {:ok, Req.Response.t()}
          | {:error, {:response, Req.Response.t()}}
          | {:error, Exception.t()}

  defprotocol IntoRequest do
    @moduledoc false

    alias Membrane.LiveCompositor.ApiClient

    @spec into_request(any()) :: ApiClient.request()
    def into_request(data)
  end

  @spec start_composing(:inet.port_number()) :: request_result()
  def start_composing(lc_port) do
    {:post, "/api/start", %{}} |> send_request(lc_port)
  end

  @spec get_status(:inet.port_number()) :: request_result()
  def get_status(lc_port) do
    {:get, "/status", nil} |> send_request(lc_port)
  end

  @spec send_request(request(), :inet.port_number()) :: request_result()
  def send_request(request, lc_port) do
    {method, route, body} = request
    {:ok, _} = Application.ensure_all_started(:req)

    retry_delay_ms = fn retry_count -> retry_count * 100 end
    req = Req.new(base_url: "http://#{@local_host_url}:#{lc_port}", retry_delay: retry_delay_ms)

    response =
      case method do
        :post -> Req.post(req, url: route, json: body)
        :get -> Req.get(req, url: route)
      end

    handle_request_result(response)
  end

  @spec handle_request_result({:ok, Req.Response.t()} | {:error, Exception.t()}) ::
          request_result()
  defp handle_request_result(req_result) do
    case req_result do
      {:ok, resp = %Req.Response{status: 200}} -> {:ok, resp}
      {:ok, resp} -> {:error, {:response, resp}}
      {:error, exception} -> {:error, exception}
    end
  end
end
