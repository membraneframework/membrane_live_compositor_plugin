alias Membrane.RawVideo
alias Membrane.VideoCompositor.Test.Utility

implementation =
  case s = System.get_env("IMPL", "nx") do
    "nx" -> :nx
    "ffmpeg" -> :ffmpeg
    "opengl" -> :opengl
    _unsupported -> raise "unsupported implementation #{s}"
  end

{sink, encoder} =
  case s = System.get_env("SINK", "file") do
    "file" -> {nil, Membrane.H264.FFmpeg.Encoder}
    "play" -> {Membrane.SDL.Player, nil}
    _unsupported -> raise "unsupported sink #{s}"
  end

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

basename = Utility.get_file_base_name(caps, 60, "h264")
demo_path = Path.join([File.cwd!(), "test", "fixtures", "demo"])
in_path = Path.join(demo_path, "in-#{basename}")
out_path = Path.join(demo_path, "out-#{basename}")

Utility.generate_testing_video(in_path, caps, 60)

paths = %{
  first_video_path: in_path,
  second_video_path: in_path,
  output_path: out_path
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
