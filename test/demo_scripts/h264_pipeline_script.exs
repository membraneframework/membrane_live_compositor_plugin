alias Membrane.RawVideo

alias Membrane.VideoCompositor.Test.Utility

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

video_duration = 10

input_path = "./tmp/input_#{video_duration}s_1080p.h264"
output_path = "./tmp/output_#{video_duration}s_2160x1080.h264"

:ok = Utility.generate_testing_video(input_path, caps, video_duration)

paths = %{
  first_video_path: input_path,
  second_video_path: input_path,
  output_path: output_path
}

implementation = :nx

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.PipelineH264.start(options)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
