alias Membrane.RawVideo

paths = %{
  first_raw_video_path: "~/membrane_video_compositor/input_60s_1080p.raw",
  second_raw_video_path: "~/membrane_video_compositor/input_60s_1080p.raw",
  output_path: "~/membrane_video_compositor/output_60s_1920x2160.raw"
}

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

implementation = :nx

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.PipelineRaw.start(options)

Process.sleep(1_000_000)
