alias Membrane.RawVideo
alias Membrane.VideoCompositor.Utility

caps = %RawVideo{
  aligned: true,
  framerate: {1, 1},
  width: 1280,
  height: 720,
  pixel_format: :I420
}

video_duration = 10

basename = Utility.get_file_base_name(caps, video_duration, "raw")
demo_path = Path.join([File.cwd!(), "lib", "tmp", "fixtures"])
in_path = Path.join(demo_path, "in-#{basename}")
out_path = Path.join(demo_path, "out-#{basename}")

Utility.generate_testing_video(in_path, caps, video_duration)

implementation =
  case s = System.get_env("IMPL", "nx") do
    "nx" -> :nx
    "ffmpeg" -> :ffmpeg
    "opengl" -> :opengl
    _unsupported -> raise "unsupported implementation #{s}"
  end

sink =
  case s = System.get_env("SINK", "file") do
    "file" -> out_path
    "play" -> Membrane.SDL.Player
    _unsupported -> raise "unsupported sink #{s}"
  end

src = in_path

paths = %{
  first_video_path: src,
  second_video_path: src,
  output_path: sink
}

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.Demo.Pipeline.Raw.start(options)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
