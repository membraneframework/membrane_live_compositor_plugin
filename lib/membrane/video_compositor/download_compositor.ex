defmodule Mix.Tasks.DownloadCompositor do
  @moduledoc """
  Downloads VideoCompositor binaries.
  """

  use Mix.Task

  @vc_version "v0.1.0-rc.2"

  @impl Mix.Task
  def run(_args) do
    vc_architecture = system_architecture() |> Atom.to_string()

    url =
      "https://github.com/membraneframework/video_compositor/releases/download/#{@vc_version}/video_compositor_#{vc_architecture}.tar.gz"

    path = File.cwd!() |> Path.join("video_compositor_app/#{vc_architecture}")

    File.mkdir_p!(path)
    _wget_res = "wget -nc #{url} -O - | tar -xvz -C #{path}" |> String.to_charlist() |> :os.cmd()
  end

  @spec system_architecture() :: :darwin_aarch64 | :darwin_x86_64 | :linux_x86_64
  defp system_architecture() do
    case :os.type() do
      {:unix, :darwin} ->
        system_architecture = :erlang.system_info(:system_architecture) |> to_string()

        cond do
          Regex.match?(~r/aarch64/, system_architecture) ->
            :darwin_aarch64

          Regex.match?(~r/x86_64/, system_architecture) ->
            :darwin_x86_64

          true ->
            raise "Unsupported system architecture: #{system_architecture}"
        end

      {:unix, :linux} ->
        :linux_x86_64

      os_type ->
        raise "Unsupported os type: #{os_type}"
    end
  end
end
