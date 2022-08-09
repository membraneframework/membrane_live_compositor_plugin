alias Membrane.RawVideo

paths = %{
  first_raw_video_path: "./test/fixtures/long_videos/input_10s_720p_1fps.raw",
  second_raw_video_path: "./test/fixtures/long_videos/input_10s_720p_1fps.raw",
  output_path: "~/membrane_video_compositor/output_10s_720p_1fps.raw"
}

caps = %RawVideo{
  aligned: true,
  framerate: {1, 1},
  width: 1280,
  height: 720,
  pixel_format: :I420
}

implementation = :nx

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation,
  return_pid: self()
}

{:ok, pid} = Membrane.VideoCompositor.PipelineRaw.start(options)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
