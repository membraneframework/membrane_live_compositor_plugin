defmodule Utils.LcServer do
  @moduledoc false

  @lc_port 8001

  @doc """
  If LIVE_COMPOSITOR_PATH env var exists start video compositor instance.
  Returns lc_server_config
  """
  @spec lc_server_config(Membrane.RawVideo.framerate_t()) ::
          :start_on_random_port | {:already_started, :inet.port_number()}
  def lc_server_config(%{framerate: framerate}) do
    case System.get_env("LIVE_COMPOSITOR_PATH") do
      nil ->
        :start_on_random_port

      lc_location ->
        start_lc_server(lc_location, framerate)
    end
  end

  defp start_lc_server(lc_location, framerate) do
    true = File.exists?(lc_location)
    case File.dir?(lc_location) do
      true -> start_lc_server_with_cargo(lc_location, framerate)
      false -> start_lc_server_executable(lc_location, framerate)
    end
  end

  defp start_lc_server_executable(lc_executable, framerate) do
    spawn(fn ->
      lc_executable
      |> MuonTrap.cmd(
        [],
        env: %{
          "LIVE_COMPOSITOR_API_PORT" => "#{@lc_port}",
          "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
        }
      )
    end)

    Process.sleep(3000)

    {:already_started, @lc_port}

  end

  defp start_lc_server_with_cargo(lc_directory_path, framerate) do
    {_, 0} =
      "cargo"
      |> MuonTrap.cmd([
        "build",
        "-r",
        "--manifest-path",
        Path.join(lc_directory_path, "Cargo.toml"),
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
          Path.join(lc_directory_path, "Cargo.toml"),
          "--bin",
          "video_compositor"
        ],
        env: %{
          "LIVE_COMPOSITOR_API_PORT" => "#{@lc_port}",
          "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
        }
      )
    end)

    Process.sleep(3000)

    {:already_started, @lc_port}
  end
end
