defmodule Mix.Tasks.DownloadCompositor do
  @moduledoc """
  Downloads VideoCompositor binaries.
  """

  use Mix.Task
  require Membrane.Logger

  @vc_version "v0.1.0-rc.2"

  @impl Mix.Task
  def run(_args) do
    url =
      "https://github.com/membraneframework/video_compositor/releases/download/#{@vc_version}/video_compositor_#{system_architecture()}.tar.gz"

    unless File.exists?(vc_app_directory()) do
      File.mkdir_p!(vc_app_directory())

      _wget_res =
        "wget -nc #{url} -O - | tar -xvz -C #{vc_app_directory()}"
        |> String.to_charlist()
        |> :os.cmd()
    end
  end

  @spec vc_app_path() :: String.t()
  def vc_app_path() do
    File.cwd!() |> Path.join("#{vc_app_directory()}/video_compositor/video_compositor")
  end

  defp vc_app_directory() do
    "video_compositor_app/#{@vc_version}/#{system_architecture()}"
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
