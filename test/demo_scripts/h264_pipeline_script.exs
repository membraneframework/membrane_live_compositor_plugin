alias Membrane.RawVideo

paths = %{
  first_video_path: "./test/fixtures/long_videos/input_60s_1080p.h264",
  second_video_path: "./test/fixtures/long_videos/input_60s_1080p.h264",
  output_path: "./test/fixtures/tmp_dir/output_120s.h264"
}

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

implementation = :nx

parser = Membrane.VideoCompositor.Demo.H264.InputParser

encoder = Membrane.H264.FFmpeg.Encoder

sink = nil
# sink = Membrane.SDL.Player

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation,
  decoder: parser,
  sink: sink,
  encoder: encoder
}

{:ok, pid} = Membrane.VideoCompositor.Demo.PipelineTemplate.start(options)

Process.sleep(1_000_000)
