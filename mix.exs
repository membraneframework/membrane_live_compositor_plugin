defmodule Membrane.Template.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_video_compositor_plugin"

  def project do
    [
      app: :membrane_video_compositor_plugin,
      version: @version,
      aliases: aliases(),
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Template Plugin for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane Template plugin",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp aliases() do
    [
      compile: ["download_compositor", "compile"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "examples"]
  defp elixirc_paths(_env), do: ["lib", "test", "examples"]

  defp deps do
    [
      # Membrane
      {:membrane_core, "~> 0.12.9"},
      ## RTP
      {:membrane_rtp_plugin, "~> 0.23.1"},
      {:membrane_rtp_h264_plugin, "~> 0.18.0"},
      {:membrane_h264_plugin, "~> 0.7.3"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.29.0"},
      {:membrane_udp_plugin, "~> 0.10.0"},
      # VC server start
      {:rambo, "~> 0.2"},
      # VC API requests
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      # Examples
      {:membrane_file_plugin, "~> 0.15.0"},
      {:membrane_realtimer_plugin, "~> 0.7.0"},
      {:membrane_sdl_plugin, "~> 0.16.0"},
      # Dev
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
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
        "Membrane Framework Homepage" => "https://membrane.stream"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Template]
    ]
  end
end
