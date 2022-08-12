alias Membrane.RawVideo
alias Membrane.VideoCompositor.Test.Utility

implementation =
  case s = System.get_env("IMPL", "nx") do
    "nx" -> :nx
    "ffmpeg" -> :ffmpeg
    "opengl" -> :opengl
    _unsupported -> raise "unsupported implementation #{s}"
  end

sink =
  case s = System.get_env("SINK", "file") do
    "file" -> nil
    "play" -> Membrane.SDL.Player
    _unsupported -> raise "unsupported sink #{s}"
  end

caps = %RawVideo{
  aligned: true,
  framerate: {1, 1},
  width: 1280,
  height: 720,
  pixel_format: :I420
}

basename = Utility.get_file_base_name(caps, 10, "raw")
demo_path = Path.join([File.cwd!(), "test", "fixtures", "demo"])
in_path = Path.join(demo_path, "in-#{basename}")
out_path = Path.join(demo_path, "out-#{basename}")

Utility.generate_testing_video(in_path, caps, 10)

paths = %{
  first_video_path: in_path,
  second_video_path: in_path,
  output_path: out_path
}

implementation = :nx

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation,
  sink: sink
}

{:ok, pid} = Membrane.VideoCompositor.PipelineRaw.start(options)

Process.sleep(1_000_000)
