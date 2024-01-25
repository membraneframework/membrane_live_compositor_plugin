defmodule Utils.VcServer do
  @moduledoc false

  @doc """
  If LIVE_COMPOSITOR_PATH env var exists start video compositor instance.
  Returns vc_server_config
  """
  @spec vc_server_config(Membrane.RawVideo.framerate_t()) ::
          :start_on_random_port | {:already_started, :inet.port_number()}
  def vc_server_config(%{framerate: framerate}) do
    case System.get_env("LIVE_COMPOSITOR_PATH") do
      nil ->
        :start_on_random_port

      vc_directory_path ->
        start_vc_server(vc_directory_path, framerate)
    end
  end

  defp start_vc_server(vc_directory_path, framerate) do
    {_, 0} =
      "cargo"
      |> MuonTrap.cmd([
        "build",
        "-r",
        "--manifest-path",
        Path.join(vc_directory_path, "Cargo.toml"),
        "--bin",
        "video_compositor"
      ],
         env: %{
          "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
        }
      )

    vc_port = 8001

    spawn(fn ->
      "cargo"
      |> MuonTrap.cmd(
        [
          "run",
          "-r",
          "--manifest-path",
          Path.join(vc_directory_path, "Cargo.toml"),
          "--bin",
          "video_compositor"
        ],
        env: %{
          "LIVE_COMPOSITOR_API_PORT" => "#{vc_port}",
          "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
        }
      )
    end)

    Process.sleep(3000)

    {:already_started, vc_port}
  end
end
