# test elixir membrane pipeline for demo of video composer

## Overview
This code aims to implement simple membrane pipeline, that allows to test function for merging two raw videos into one, by placing first one above the other.

### Current state:
Something f****-up in video compositor element and it's too late for me to debug it :)

### Overview of pipeline:
Pipeline starts with two Membrane.File.Source elements, that feed data into two Membrane.RawVideo.Parser-s. Parsers are connected to VideoComposer element, which is responsible for merging recived frames buffers and send them throught in buffers to video encoder or to sink pad.

### Videos specs:
Video format: raw video
Resolution: 1280x720
Framerate: 30
Pixel format: I420


