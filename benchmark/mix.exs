defmodule Membrane.VideoCompositor.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_video_compositor_plugin"

  def project do
    [
      app: :membrane_video_compositor_plugin_benchmark,
      version: @version,
      elixir: "~> 1.13",
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Benchmark for Video Compositor Plugin for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane Video Compositor plugin",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_video_compositor_plugin, path: ".."},
      {:membrane_core, "~> 0.10.0"},
      {:membrane_file_plugin, "~> 0.12.0"},
      {:membrane_raw_video_parser_plugin, "~> 0.8.0"},
      {:membrane_caps_video_raw, "~> 0.1.0"},
      {:membrane_raw_video_format, "~> 0.2.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.21.1"},
      {:membrane_common_c, "~> 0.13.0"},
      {:benchee, "~> 1.1.0"},
      {:benchee_html, "~> 1.0"},
      {:beamchmark, "~> 1.4.0"},
      {:mock, "~> 0.3.0"},
      {:nx, "~> 0.2"},
      {:exla, "~> 0.2"},
      {:unifex, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling],
      plt_add_apps: [:ex_unit]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.VideoCompositor]
    ]
  end
end
