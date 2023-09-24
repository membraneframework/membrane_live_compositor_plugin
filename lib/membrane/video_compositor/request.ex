defmodule Membrane.VideoCompositor.Request do
  @moduledoc false

  alias Membrane.VideoCompositor

  @video_compositor_server_ip {127, 0, 0, 1}
  @video_compositor_server_port 8001

  @receive_streams_ip_address {127, 0, 0, 2}

  @spec init(non_neg_integer(), Membrane.Time.t(), boolean()) :: :ok | {:error, String.t()}
  def init(framerate, stream_fallback_timeout, init_web_renderer?) do
    vc_url = ip_to_url(@video_compositor_server_ip, @video_compositor_server_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "init",
          web_renderer: %{
            init: init_web_renderer?
          },
          framerate: framerate,
          stream_fallback_timeout: Membrane.Time.as_milliseconds(stream_fallback_timeout, :round)
        }
      )

    case req_result do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, resp} -> {:error, resp}
      {:error, exception} -> {:error, exception}
    end
  end

  @spec start_composing() :: :ok | {:error, String.t()}
  def start_composing() do
    vc_url = ip_to_url(@video_compositor_server_ip, @video_compositor_server_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "start"
        }
      )

    case req_result do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, resp} -> {:error, resp}
      {:error, exception} -> {:error, exception}
    end
  end

  @spec register_input_stream(VideoCompositor.input_id(), VideoCompositor.port_number()) ::
          :ok
          | {:error, Req.Response.t() | Exception.t()}
  def register_input_stream(input_id, port_number) do
    vc_url = ip_to_url(@video_compositor_server_ip, @video_compositor_server_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "register",
          entity_type: "input_stream",
          input_id: "#{input_id}",
          port: port_number
        }
      )

    case req_result do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, resp} -> {:error, resp}
      {:error, exception} -> {:error, exception}
    end
  end

  @spec register_output_stream(
          VideoCompositor.output_id(),
          VideoCompositor.port_number(),
          Resolution.t()
        ) ::
          :ok | {:error, Req.Response.t() | Exception.t()}
  def register_output_stream(output_id, port_number, resolution) do
    vc_url = ip_to_url(@video_compositor_server_ip, @video_compositor_server_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "register",
          entity_type: "output_stream",
          output_id: output_id,
          port: port_number,
          ip: ip_to_str(@receive_streams_ip_address),
          resolution: %{
            width: resolution.width,
            height: resolution.height
          }
        }
      )

    case req_result do
      {:ok, %Req.Response{status: 200}} -> :ok
      {:ok, resp} -> {:error, resp}
      {:error, exception} -> {:error, exception}
    end
  end

  @spec ip_to_url(VideoCompositor.ip(), VideoCompositor.port_number()) :: String.t()
  def ip_to_url(ip, port_number) do
    ip_str = ip_to_str(ip)
    "http://#{ip_str}:#{port_number}"
  end

  @spec ip_to_str(VideoCompositor.ip()) :: String.t()
  def ip_to_str({ip_0, ip_1, ip_2, ip_3}) do
    "#{ip_0}.#{ip_1}.#{ip_2}.#{ip_3}"
  end
end
