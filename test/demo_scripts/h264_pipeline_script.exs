alias Membrane.RawVideo

paths = %{
  first_video_path: "~/membrane_video_compositor/input_120s_4k.h264",
  second_video_path: "~/membrane_video_compositor/input_120s_4k.h264",
  output_path: "~/membrane_video_compositor/output_120s.h264"
}

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 3840,
  height: 2160,
  pixel_format: :I420
}

implementation = :nx

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.PipelineH264.start(options)

Process.sleep(1_000_000)
