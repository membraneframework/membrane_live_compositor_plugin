alias Membrane.RawVideo

implementation =
  case s = System.get_env("IMPL", "nx") do
    "nx" -> :nx
    "ffmpeg" -> :ffmpeg
    "opengl" -> :opengl
    _ -> raise "unsupported implementation #{s}"
  end

{sink, encoder} =
  case s = System.get_env("SINK", "file") do
    "file" -> {nil, Membrane.H264.FFmpeg.Encoder}
    "play" -> {Membrane.SDL.Player, nil}
    _ -> raise "unsupported sink #{s}"
  end

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

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation,
  encoder: encoder,
  sink: sink
}

{:ok, _pid} = Membrane.VideoCompositor.PipelineH264.start(options)

Process.sleep(1_000_000)
