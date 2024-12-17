defmodule Membrane.LiveCompositor.Mixfile do
  use Mix.Project

  @version "0.10.0"
  @github_url "https://github.com/membraneframework/membrane_live_compositor_plugin"

  def project do
    [
      app: :membrane_live_compositor_plugin,
      version: @version,
      compilers: compilers(),
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "LiveCompositor SDK for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane LiveCompositor Plugin",
      source_url: @github_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp compilers() do
    Mix.compilers() ++ [:download_compositor]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib", "test"]

  defp deps do
    [
      # Membrane
      {:membrane_core, "~> 1.0"},
      {:membrane_raw_video_format, "~> 0.3.0"},
      {:membrane_opus_plugin, "~> 0.20.4"},
      ## RTP
      {:membrane_rtp_plugin, "~> 0.29.0"},
      {:membrane_rtp_h264_plugin, "~> 0.20.0"},
      {:membrane_tcp_plugin, "~> 0.6.0"},
      {:membrane_rtp_opus_plugin, "~> 0.9.0"},
      # VC server start
      {:muontrap, "~> 1.0"},
      # VC API
      {:req, "~> 0.4.0"},
      {:websockex, "~> 0.4.3"},
      {:jason, "~> 1.4"},
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

  defp package do
    [
      maintainers: ["Software Mansion"],
      licenses: ["BUSL-1.1"],
      links: %{
        "GitHub" => @github_url,
        "Live Compositor Homepage" => "https://compositor.live",
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
      nest_modules_by_prefix: [Membrane.LiveCompositor, Membrane.LiveCompositor.Request],
      groups_for_modules: [
        Encoders: [
          ~r/^Membrane\.LiveCompositor\.Encoder($|\.)/
        ],
        Requests: [
          ~r/^Membrane\.LiveCompositor\.Request($|\.)/
        ]
      ]
    ]
  end
end
