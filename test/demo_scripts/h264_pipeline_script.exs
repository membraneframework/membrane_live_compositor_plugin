alias Membrane.RawVideo

paths = %{
  first_h264_video_path: "./test/fixtures/long_videos/input_60s_1080p.h264",
  second_h264_video_path: "./test/fixtures/long_videos/input_60s_1080p.h264",
  output_path: "~/membrane_video_compositor/output_60s.h264"
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
  implementation: implementation,
  return_pid: self()
}

{:ok, pid} = Membrane.VideoCompositor.PipelineH264.start(options)

receive do
  :finished -> :ok
end
