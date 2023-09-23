defmodule Membrane.VideoCompositor.Utils do
  @moduledoc false
  alias Membrane.VideoCompositor

  @spec ip_to_url(VideoCompositor.ip(), VideoCompositor.port()) :: String.t()
  def ip_to_url(ip, port_number) do
    ip_str = ip_to_str(ip)
    "http://#{ip_str}:#{port_number}"
  end

  @spec ip_to_str(VideoCompositor.ip())
  def ip_to_str({ip_0, ip_1, ip_2, ip_3}) do
    "#{ip_0}.#{ip_1}.#{ip_2}.#{ip_3}"
  end
end
