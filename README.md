# Membrane Video Compositor Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_compositor_plugin.svg)](https://hex.pm/packages/membrane_video_compositor_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_video_compositor_plugin)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/membraneframework/membrane_video_compositor_plugin/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/membraneframework/membrane_video_compositor_plugin/tree/master)

Membrane SDK for VideoCompositor, that takes multiple input streams, transforms them according to provided transformations and composes them into output streams / videos.

It is part of [Membrane Multimedia Framework](https://membrane.stream).

## Installation

The package can be installed by adding `membrane_video_compositor_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_video_compositor_plugin, "~> 0.8.0"}
  ]
end
```

VideoCompositor requires having locally installed:

- [FFmpeg 6.0](https://ffmpeg.org/download.html) - for streaming inputs / outputs to VideoCompositor
- [wget](https://www.gnu.org/software/wget/) - for downloading VideoCompositor binary file
- [tar](https://www.gnu.org/software/tar/) - for decompressing VideoCompositor binary file

## Examples

Examples can be found in `examples` directory.

To run example run:

1. `cd examples`
2. `mix deps.get`
3. `mix run [example_name].exs`

### Layout with shader example

The example presents dynamically added video arranged onto a tiled layout and "twisted" with the simple shader. Shaders can be used to create custom visual effects.

### Transition example

The example presents dynamic transition of input videos. Transitions are used for smooth, dynamical animations.

### Dynamic outputs example

The example presents dynamic outputs linking.
Multiple outputs are useful for live-streaming for multiple platforms (e.g. different layout for mobile devices), target resolutions
or any other case, when user want to process input videos differently.
