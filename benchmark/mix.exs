defmodule Membrane.VideoCompositor.Benchmark.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_video_compositor_plugin"

  def project do
    [
      app: :membrane_video_compositor_plugin,
      version: @version,
      elixir: "~> 1.13",
      compilers: [:unifex],
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Benchmark of Video Compositor Plugin for Membrane Multimedia Framework",
      package: package(),

      # docs
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: []
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_video_compositor_plugin, path: ".."},
      {:benchee, "~> 1.1.0"},
      {:benchee_html, "~> 1.0"},
      {:beamchmark, "~> 1.4.0"},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
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
      extras: ["README.md"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.VideoCompositor]
    ]
  end
end
