defmodule Mix.Tasks.Compile.DownloadCompositor do
  @moduledoc false
  # Downloads VideoCompositor binaries.

  use Mix.Task
  require Membrane.Logger

  @vc_version "v0.1.0-rc.2"
  @membrane_video_compositor_plugin_path File.cwd!()

  @impl Mix.Task
  def run(_args) do
    url =
      "https://github.com/membraneframework/video_compositor/releases/download/#{@vc_version}/video_compositor_#{system_architecture()}.tar.gz"

    unless File.exists?(vc_app_directory()) do
      File.mkdir_p!(vc_app_directory())
      Membrane.Logger.info("Downloading VideoCompositor binary")

      tmp_path = @membrane_video_compositor_plugin_path |> Path.join("tmp")
      File.mkdir_p!(tmp_path)

      wget_res_path = Path.join(tmp_path, "video_compositor")
      System.cmd("wget", ["-O", wget_res_path, url])
      System.cmd("tar", ["-xvf", wget_res_path, "-C", vc_app_directory()])
      File.rm_rf!(wget_res_path)
    end
    
    :ok
  end

  @spec vc_app_path() :: String.t()
  def vc_app_path() do
    Path.join(vc_app_directory(), "video_compositor/video_compositor")
  end

  defp vc_app_directory() do
    @membrane_video_compositor_plugin_path
    |> Path.join("priv/#{@vc_version}/#{system_architecture()}")
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
