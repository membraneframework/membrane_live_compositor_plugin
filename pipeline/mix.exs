defmodule Membrane.VideoCompositor.Pipeline.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :membrane_video_compositor_plugin_pipeline,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 0.10.0"},
      {:membrane_raw_video_format, "~> 0.2.0"},
      {:membrane_file_plugin, "~> 0.12.0"}
    ]
  end
end
