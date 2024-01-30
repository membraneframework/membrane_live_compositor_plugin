defmodule Utils.VcServer do
  @moduledoc false

  @vc_port 8001

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

      vc_location ->
        start_vc_server(vc_location, framerate)
    end
  end

  defp start_vc_server(vc_location, framerate) do
    true = File.exists?(vc_location)
    case File.dir?(vc_location) do
      true -> start_vc_server_with_cargo(vc_location, framerate)
      false -> start_vc_server_executable(vc_location, framerate)
    end
  end

  defp start_vc_server_executable(vc_executable, framerate) do
    spawn(fn ->
      vc_executable
      |> MuonTrap.cmd(
        [],
        env: %{
          "LIVE_COMPOSITOR_API_PORT" => "#{@vc_port}",
          "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
        }
      )
    end)

    Process.sleep(3000)

    {:already_started, @vc_port}

  end

  defp start_vc_server_with_cargo(vc_directory_path, framerate) do
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
          "LIVE_COMPOSITOR_API_PORT" => "#{@vc_port}",
          "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
        }
      )
    end)

    Process.sleep(3000)

    {:already_started, @vc_port}
  end
end
