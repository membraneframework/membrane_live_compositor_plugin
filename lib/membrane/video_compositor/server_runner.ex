defmodule Membrane.LiveCompositor.ServerRunner do
  @moduledoc false

  alias Membrane.LiveCompositor.Request

  @spec start_lc_server(:inet.port_number(), map()) :: :ok | :error
  def start_lc_server(lc_port, env) do
    video_compositor_app_path = Mix.Tasks.Compile.DownloadCompositor.lc_app_path()

    unless File.exists?(video_compositor_app_path) do
      raise "Live Compositor binary is not available under search path: \"#{video_compositor_app_path}\"."
    end

    pid =
      spawn(fn ->
        video_compositor_app_path
        |> MuonTrap.cmd([],
          env:
            Map.merge(
              %{"LIVE_COMPOSITOR_API_PORT" => "#{lc_port}"},
              env
            )
        )
      end)

    case wait_for_lc_startup(lc_port) do
      :started ->
        :ok

      :not_started ->
        Process.exit(pid, :normal)
        :error
    end
  end

  @spec wait_for_lc_startup(:inet.port_number()) :: :started | :not_started
  defp wait_for_lc_startup(lc_port) do
    0..300
    |> Enum.reduce_while(:not_started, fn _i, _acc ->
      Process.sleep(100)

      case Request.get_status(lc_port) do
        {:ok, _} ->
          {:halt, :started}

        {:error, _reason} ->
          {:cont, :not_started}
      end
    end)
  end
end
