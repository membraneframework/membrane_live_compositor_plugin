first_raw_video_path = "~/membrane_video_compositor/testsrc.raw"
second_raw_video_path = "~/membrane_video_compositor/testsrc.raw"
output_path = "~/membrane_video_compositor/output.h264"

video_width = 1280
video_height = 720
video_framerate = 30
implementation = :nx  # one of :ffmpeg, :opengl, :nx

options = [%{
  first_raw_video_path: first_raw_video_path,
  second_raw_video_path: second_raw_video_path,
  output_path: output_path,
  video_width: video_width,
  video_height: video_height,
  video_framerate: video_framerate,
  implementation: implementation
}]

{:ok, pid} =
  Membrane.VideoCompositor.Pipeline.start(options)

Membrane.VideoCompositor.Pipeline.play(pid)
Process.sleep(100000)  # will be removed with implementation of beamchmark
