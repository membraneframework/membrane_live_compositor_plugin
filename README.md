# Membrane Video Compositor Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_compositor_plugin.svg)](https://hex.pm/packages/membrane_video_compositor_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_video_compositor_plugin)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/membraneframework/membrane_video_compositor_plugin/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/membraneframework/membrane_video_compositor_plugin/tree/master)

Membrane plugin that accepts multiple video inputs, transforms them according to provided transformations and composes them into video outputs.

It is part of [Membrane Multimedia Framework](https://membrane.stream).

## Installation

The package can be installed by adding `membrane_video_compositor_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_video_compositor_plugin, "~> 0.5.4"}
  ]
end
```

and specifying `:membrane_rtp_h264_plugin` as an extra application:

```elixir
def application do
  [
    extra_applications: [:membrane_rtp_h264_plugin]
  ]
end
```

## Examples

Examples can be found in `examples` directory.

To run example run:

1. `mix deps.get`
2. `mix run examples/[example_name].exs`

### Layout with shader example

Example presents dynamically added video arranged onto tiled layout and "twisted" with simple shader. Shaders can be used to create custom visual effects.

### Transition example

Example presents dynamic transition of input videos. Transitions are used for smooth, dynamical animations.

### Dynamic outputs example

Example presents dynamic outputs linking.
Multiple outputs are useful for live-streaming for multiple platforms (e.g. different layout for mobile devices), target resolutions
or any other case, when user want to process input videos in different ways.
