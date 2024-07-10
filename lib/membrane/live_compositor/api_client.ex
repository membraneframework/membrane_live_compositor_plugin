defmodule Membrane.LiveCompositor.ApiClient do
  @moduledoc false

  require Membrane.Logger

  alias Membrane.LiveCompositor

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

  @spec request_keyframe(:inet.port_number(), LiveCompositor.output_id()) :: request_result()
  def request_keyframe(lc_port, output_id) do
    {:post, "/api/output/#{output_id}/request_keyframe", %{}} |> send_request(lc_port)
  end

  @spec send_request(request(), :inet.port_number()) :: request_result()
  def send_request(request, lc_port) do
    {method, route, body} = request
    url = lc_url(lc_port, route)

    {:ok, _} = Application.ensure_all_started(:req)

    response =
      case method do
        :post -> Req.post(url, json: body)
        :get -> Req.get(url)
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

  defp lc_url(lc_server_port, route) do
    "http://#{@local_host_url}:#{lc_server_port}#{route}"
  end
end
