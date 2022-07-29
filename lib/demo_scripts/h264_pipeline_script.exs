alias Membrane.RawVideo

paths = %{
  first_h264_video_path: "~/membrane_video_compositor/input_30s_720p.h264",
  second_h264_video_path: "~/membrane_video_compositor/input_30s_720p.h264",
  output_path: "~/membrane_video_compositor/output_30s_1280x1440.h264"
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

{:ok, pid} = Membrane.VideoCompositor.PipelineH264.start(options)
