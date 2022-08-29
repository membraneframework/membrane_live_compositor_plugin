# Demos for Membrane Video Compositor Plugin

<!-- [![Hex.pm](https://img.shields.io/hexpm/v/membrane_video_compositor_plugin.svg)](https://hex.pm/packages/membrane_video_compositor_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_video_compositor_plugin) -->
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/membraneframework-labs/membrane_video_compositor_plugin/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/membraneframework-labs/membrane_video_compositor_plugin/tree/master)

Set of demos for Membrane video compositor plugin. 


## Usage

Run demos with the command line, for example:

`IMPL=ffmpeg SINK=file  mix run lib/h264_pipeline_script.exs`

### Possible options:
- `IMPL=` - implementation of video compositor 
  - `ffmpeg`
  - `nx`
  - `opengl_cpp`
  - `opengl_rust`
  
- `SINK=` - result destination
  - `file` - create an output file with the corresponding video format
  - `play` - play result in real-time, using SDL video player

### Currently available demos:
 - `lib/h264_pipeline_script.exs` - 60 seconds, 30 fps, full-hd (`SINK=play` is not supported right now)
 - `lib/raw_pipeline_script.exs` - 10 seconds, 1 fps, hd

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_compositor_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_video_compositor_plugin)

Licensed under the [Apache License, Version 2.0](../LICENSE)
