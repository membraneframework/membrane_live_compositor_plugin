defmodule Membrane.VideoCompositor.Demo do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_video_compositor_plugin"

  def project do
    [
      app: :membrane_video_compositor_plugin_demo,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Demos for Video Compositor for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane Video Compositor plugin",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 0.10.0"},
      {:membrane_video_compositor_plugin, path: ".."},
      {:membrane_file_plugin, "~> 0.12.0"},
      {:membrane_sdl_plugin, "~> 0.14.0"},
      {:membrane_raw_video_format, "~> 0.2.0"},

      # Development
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
end
