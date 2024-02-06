defmodule Membrane.LiveCompositor.ServerRunner do
  @moduledoc false

  require Membrane.Logger

  alias Membrane.LiveCompositor
  alias Membrane.LiveCompositor.Request

  @spec start_server(:inet.port_number() | LiveCompositor.port_range(), map()) ::
          {:ok, :inet.port_number()} | {:error, err :: String.t()}
  def start_server(port_or_port_range, env) do
    {port_lower_bound, port_upper_bound} =
      case port_or_port_range do
        {start, endd} -> {start, endd}
        exact -> {exact, exact + 1}
      end

    port_lower_bound..port_upper_bound
    |> Enum.shuffle()
    |> Enum.reduce_while(
      {:error, "Failed to start a LiveCompositor server on any of the ports."},
      fn port, err -> try_starting_on_port(port, err, env) end
    )
  end

  @spec try_starting_on_port(:inet.port_number(), String.t(), map()) ::
          {:halt, {:ok, :inet.port_number()}} | {:cont, err :: String.t()}
  defp try_starting_on_port(port, err, env) do
    Membrane.Logger.debug("Trying to launch LiveCompositor on port: #{port}")

    case start_on_port(port, env) do
      :ok -> {:halt, {:ok, port}}
      :error -> {:cont, err}
    end
  end

  @spec start_on_port(:inet.port_number(), map()) :: :ok | :error
  defp start_on_port(lc_port, env) do
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
              %{
                "LIVE_COMPOSITOR_API_PORT" => "#{lc_port}",
                "LIVE_COMPOSITOR_WEB_RENDERER_ENABLE" => "false"
              },
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
