alias Membrane.RawVideo

paths = %{
  first_raw_video_path: "~/membrane_video_compositor/input_30s_720p.raw",
  second_raw_video_path: "~/membrane_video_compositor/input_30s_720p.raw",
  output_path: "~/membrane_video_compositor/output_30s_720p.raw"
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

{:ok, pid} = Membrane.VideoCompositor.PipelineRaw.start(options)

Membrane.VideoCompositor.PipelineRaw.play(pid)
# will be removed with implementation of Membrane Beamchmark
Process.sleep(1_000_000)
