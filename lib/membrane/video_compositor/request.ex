defmodule Membrane.VideoCompositor.Request do
  @moduledoc false

  require Membrane.Logger

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Resolution

  @local_host {127, 0, 0, 1}

  @type req_result :: :ok | {:error, Req.Response.t() | Exception.t()}

  @spec init(non_neg_integer(), Membrane.Time.t(), boolean(), VideoCompositor.port_number()) ::
          :ok | {:error, String.t()}
  def init(framerate, stream_fallback_timeout, init_web_renderer?, vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

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

    handle_req_result(req_result)
  end

  @spec start_composing(VideoCompositor.port_number()) :: :ok | {:error, String.t()}
  def start_composing(vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "start"
        }
      )

    handle_req_result(req_result)
  end

  @spec send_custom_request(map(), VideoCompositor.port_number()) ::
          {:ok, Req.Response.t()} | {:error, any()}
  def send_custom_request(request_body, vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

    Req.post(vc_url,
      json: request_body
    )
  end

  @spec register_input_stream(
          VideoCompositor.input_id(),
          VideoCompositor.port_number(),
          VideoCompositor.port_number()
        ) ::
          req_result()
  def register_input_stream(input_id, input_port_number, vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "register",
          entity_type: "input_stream",
          input_id: "#{input_id}",
          port: input_port_number
        }
      )

    handle_req_result(req_result)
  end

  @spec unregister_input_stream(VideoCompositor.input_id(), VideoCompositor.port_number()) ::
          req_result()
  def unregister_input_stream(input_id, vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "unregister",
          entity_type: "input_stream",
          input_id: input_id
        }
      )

    handle_req_result(req_result)
  end

  @spec unregister_output_stream(VideoCompositor.output_id(), VideoCompositor.port_number()) :: req_result()
  def unregister_output_stream(output_id, vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "unregister",
          entity_type: "output_stream",
          input_id: output_id
        }
      )

    handle_req_result(req_result)
  end

  @spec register_output_stream(
          VideoCompositor.output_id(),
          VideoCompositor.port_number(),
          Resolution.t(),
          VideoCompositor.encoder_preset(),
          VideoCompositor.port_number()
        ) :: req_result()
  def register_output_stream(output_id, port_number, resolution, encoder_preset, vc_port) do
    vc_url = ip_to_url(@local_host, vc_port)

    req_result =
      Req.post(vc_url,
        json: %{
          type: "register",
          entity_type: "output_stream",
          output_id: output_id,
          port: port_number,
          ip: ip_to_str(@local_host),
          resolution: %{
            width: resolution.width,
            height: resolution.height
          },
          encoder_settings: %{
            preset: encoder_preset
          }
        }
      )

    handle_req_result(req_result)
  end

  defp handle_req_result(req_result) do
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
