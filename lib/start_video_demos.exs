alias Membrane.RawVideo

paths = %{
  first_raw_video_path: "~/membrane_video_compositor/testsrc.raw",
  second_raw_video_path: "~/membrane_video_compositor/testsrc.raw",
  output_path: "~/membrane_video_compositor/output.raw"
}

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1280,
  height: 720,
  pixel_format: :I420
}

implementation = :nx

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.Pipeline.start(options)

Membrane.VideoCompositor.Pipeline.play(pid)
# will be removed with implementation of Membrane Beamchmark
Process.sleep(100_000)
