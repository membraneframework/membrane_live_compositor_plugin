defmodule Membrane.VideoCompositor.ServerRunner do
  @moduledoc false

  alias Membrane.VideoCompositor.Request

  @spec start_vc_server(:inet.port_number()) :: :ok | :error
  def start_vc_server(vc_port) do
    pid =
      case server_path() do
        {:binary, app_path} ->
          unless File.exists?(app_path) do
            raise "Video Compositor binary is not available under search path: \"#{app_path}\"."
          end

          spawn(fn ->
            app_path
            |> MuonTrap.cmd([], env: %{"MEMBRANE_VIDEO_COMPOSITOR_API_PORT" => "#{vc_port}"})
          end)

        {:project, project_path} ->
          unless File.dir?(project_path) do
            raise "Video Compositor project is not available under search path: \"#{project_path}\"."
          end

          spawn(fn ->
            "cargo"
            |> MuonTrap.cmd(
              [
                "run",
                "-r",
                "--manifest-path",
                Path.join(project_path, "Cargo.toml"),
                "--bin",
                "video_compositor"
              ],
              env: %{"MEMBRANE_VIDEO_COMPOSITOR_API_PORT" => "#{vc_port}"}
            )
          end)
      end

    case wait_for_vc_startup(vc_port) do
      :started ->
        :ok

      :not_started ->
        Process.exit(pid, :normal)
        :error
    end
  end

  @spec server_path() :: {:binary, String.t()} | {:project, String.t()}
  def server_path() do
    case System.get_env("VC_PATH") do
      nil ->
        {:binary, Mix.Tasks.Compile.PrepareCompositor.app_path()}

      env ->
        if File.dir?(env) do
          {:project, env}
        else
          raise """
          Path in VC_PATH is set to #{env} value, which is not a valid directory.
          Provide a valid path to the VideoCompositor directory or
          remove VC_PATH env var to automatically download and run a suitable binary.
          """
        end
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
