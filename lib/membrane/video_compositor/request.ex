defmodule Membrane.VideoCompositor.Request do
  @moduledoc false

  @video_compositor_server_ip {127, 0, 0, 1}
  @video_compositor_server_port 8001

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

  @spec register_input_stream(String.t(), non_neg_integer()) ::
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

  @spec register_output_stream(String.t(), non_neg_integer(), Resolution.t()) ::
          :ok | {:error, Req.Response.t() | Exception.t()}
  defp register_output_stream(output_id, port_number, resolution) do
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
end
