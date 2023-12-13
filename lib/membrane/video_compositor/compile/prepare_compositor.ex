defmodule Mix.Tasks.Compile.PrepareCompositor do
  @moduledoc false

  use Mix.Task
  require Membrane.Logger

  alias Membrane.VideoCompositor.ServerRunner

  @vc_version "v0.2.0-rc.0"

  @impl Mix.Task
  def run(_args) do
    case ServerRunner.server_path() do
      {:binary, _path} ->
        lock_path = download_dir_path() |> Path.join("vc.lock")

        unless File.exists?(lock_path) do
          download_dir_path = download_dir_path()

          url =
            "https://github.com/membraneframework/video_compositor/releases/download/#{@vc_version}/video_compositor_#{system_architecture()}.tar.gz"

          File.mkdir_p!(download_dir_path())
          Membrane.Logger.info("Downloading VideoCompositor binary")

          tmp_path = :code.priv_dir(:membrane_video_compositor_plugin) |> Path.join("tmp")
          File.mkdir_p!(tmp_path)

          wget_res_path = Path.join(tmp_path, "video_compositor")
          MuonTrap.cmd("wget", ["-O", wget_res_path, url])
          MuonTrap.cmd("tar", ["-xvf", wget_res_path, "-C", download_dir_path])
          File.rm_rf!(wget_res_path)
          File.touch!(lock_path)
        end

        :ok

      {:project, path} ->
        "cargo"
        |> MuonTrap.cmd([
          "build",
          "-r",
          "--manifest-path",
          Path.join(path, "Cargo.toml"),
          "--bin",
          "video_compositor"
        ])

        :ok
    end
  end

  @spec binary_app_path() :: String.t()
  def binary_app_path() do
    Path.join(download_dir_path(), "video_compositor/video_compositor")
  end

  defp download_dir_path() do
    :code.priv_dir(:membrane_video_compositor_plugin)
    |> Path.join("#{@vc_version}/#{system_architecture()}")
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
