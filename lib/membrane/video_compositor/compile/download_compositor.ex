defmodule Mix.Tasks.Compile.DownloadCompositor do
  @moduledoc false
  # Downloads LiveCompositor binaries.

  use Mix.Task
  require Membrane.Logger

  @lc_version "v0.2.0-rc.1"

  @impl Mix.Task
  def run(_args) do
    url =
      "https://github.com/membraneframework/video_compositor/releases/download/#{@lc_version}/video_compositor_#{system_architecture()}.tar.gz"

    lock_path = lc_app_directory() |> Path.join(".lock")

    unless File.exists?(lock_path) do
      File.mkdir_p!(lc_app_directory())
      Membrane.Logger.info("Downloading LiveCompositor binary")

      tmp_path = :code.priv_dir(:membrane_video_compositor_plugin) |> Path.join("tmp")
      File.mkdir_p!(tmp_path)

      wget_res_path = Path.join(tmp_path, "video_compositor")
      MuonTrap.cmd("wget", ["-O", wget_res_path, url])
      MuonTrap.cmd("tar", ["-xvf", wget_res_path, "-C", lc_app_directory()])
      File.rm_rf!(wget_res_path)
      File.touch!(lock_path)
    end

    :ok
  end

  @spec lc_app_path() :: String.t()
  def lc_app_path() do
    Path.join(lc_app_directory(), "video_compositor/video_compositor")
  end

  defp lc_app_directory() do
    :code.priv_dir(:membrane_video_compositor_plugin)
    |> Path.join("#{@lc_version}/#{system_architecture()}")
  end

  @spec system_architecture() :: String.t()
  defp system_architecture() do
    case :os.type() do
      {:unix, :darwin} ->
        system_architecture = :erlang.system_info(:system_architecture) |> to_string()

        cond do
          Regex.match?(~r/aarch64/, system_architecture) ->
            "darwin_aarch64"

          Regex.match?(~r/x86_64/, system_architecture) ->
            "darwin_x86_64"

          true ->
            raise "Unsupported system architecture: #{system_architecture}"
        end

      {:unix, :linux} ->
        "linux_x86_64"

      os_type ->
        raise "Unsupported os type: #{os_type}"
    end
  end
end
