defmodule Membrane.VideoCompositor.Examples.Mixfile do
  use Mix.Project

  @version "0.5.4"

  def project do
    [
      app: :membrane_video_compositor_plugin_examples,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:membrane_rtp_h264_plugin]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib", "test"]

  defp deps do
    [
      # Membrane
      {:membrane_core, "~> 0.12.9"},
      {:membrane_video_compositor_plugin, path: "..", app: false},
      # VC API requests
      {:req, "~> 0.4.0"},
      # Examples
      {:membrane_file_plugin, "~> 0.15.0"},
      {:membrane_realtimer_plugin, "~> 0.7.0"},
      {:membrane_sdl_plugin, "~> 0.16.0"},
      {:membrane_h264_plugin, "~> 0.7.3"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.29.0"},
      # Dev
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling],
      plt_add_apps: [:mix]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end
end
