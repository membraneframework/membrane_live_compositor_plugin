defmodule Membrane.VideoCompositor.ServerRunner do
  @moduledoc false

  alias Membrane.VideoCompositor.Request

  @spec start_vc_server(:inet.port_number()) :: :ok | :error
  def start_vc_server(vc_port) do
    video_compositor_app_path = Mix.Tasks.Compile.DownloadCompositor.vc_app_path()

    unless File.exists?(video_compositor_app_path) do
      raise "Video Compositor binary is not available under search path: \"#{video_compositor_app_path}\"."
    end

    pid = spawn(fn ->
      video_compositor_app_path
      |> MuonTrap.cmd([], env: %{"MEMBRANE_VIDEO_COMPOSITOR_API_PORT" => "#{vc_port}"})
    end)

    case wait_for_vc_startup(vc_port) do
      :started -> :ok
      :not_started ->
        Process.exit(pid, :normal)
        :error
    end
  end

  @spec wait_for_vc_startup(:inet.port_number()) :: :started | :not_started
  defp wait_for_vc_startup(vc_port) do
    0..30
    |> Enum.reduce_while(:not_started, fn _i, _acc ->
      Process.sleep(100)

      case Request.send_request(%{}, vc_port) do
        {:error_response_code, _} ->
          {:halt, :started}

        {:error, _reason} ->
          {:cont, :not_started}
      end
    end)
  end
end
