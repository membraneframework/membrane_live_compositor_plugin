first_raw_video_path = "~/Development/membrane_video_compositor_plugin/test/fixtures/4s_30fps.raw"

second_raw_video_path =
  "~/Development/membrane_video_compositor_plugin/test/fixtures/4s_30fps.raw"

output_path = "~/Development/membrane_video_compositor_plugin/test/fixtures/output.h264"

video_width = 1280
video_height = 720
video_framerate = 30
# implementation is one of: :ffmpeg, :opengl, :nx
implementation = :ffmpeg

options = %{
  first_raw_video_path: first_raw_video_path,
  second_raw_video_path: second_raw_video_path,
  output_path: output_path,
  video_width: video_width,
  video_height: video_height,
  video_framerate: video_framerate,
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.Pipeline.start(options)

Membrane.VideoCompositor.Pipeline.play(pid)
# will be removed with implementation of beamchmark
ref = Process.monitor(pid)

receive do
  # {_, _ref, :process, pid, _reason} ->
  _ ->
    IO.inspect("Done 1")
    # code
end

IO.inspect("Done 2")
# Process.sleep(100_000)
