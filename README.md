# Membrane Video Compositor Plugin

<!-- [![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_compositor_plugin.svg)](https://hex.pm/packages/membrane_video_compositor_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_video_compositor_plugin) -->
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/membraneframework-labs/membrane_video_compositor_plugin/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/membraneframework-labs/membrane_video_compositor_plugin/tree/master)

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_video_compositor_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_video_compositor_plugin, "~> 0.1.0"}
  ]
end
```

Since parts of this package are implemented in Rust, you need to have a Rust installation to compile this package. You can get one [here](https://rustup.rs/)

To compile on macOS, first get and compile [Google ANGLE](https://github.com/google/angle/blob/main/doc/DevSetup.md) with `is_component_build = false` and place the resulting `libEGL.dylib` and `libGLESv2.dylib` in the root of this package.

## Usage

TODO

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_compositor_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_compositor_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
