# template membrane pipeline for demo of video composer

## Overview
This code aims to implement simple membrane pipeline, that allows to test function for merging two raw videos into one, by placing first one above the other.

### Current state:
Something fucks-up in video compositor element and it's too late for me to debug it :)

### Overview of pipeline:
Pipeline starts with two Membrane.File.Source elements, that feed data into two Membrane.RawVideo.Parser-s. Parsers are connected to VideoComposer element, which is responsible for merging recived frames buffers and send them throught in buffers to video encoder or to sink pad.

### deps:
defp deps do
    [
      {:membrane_core, "~> 0.10.0"},
      {:membrane_file_plugin, "~> 0.12.0"},
      {:membrane_raw_video_parser_plugin, "~> 0.8.0"},
      {:membrane_caps_video_raw, "~> 0.1.0"},
      {:membrane_raw_video_format, "~> 0.2.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.21.1"},
      {:mock, "~> 0.3.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
end
