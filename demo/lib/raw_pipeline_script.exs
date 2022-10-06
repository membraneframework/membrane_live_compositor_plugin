alias Membrane.RawVideo
alias Membrane.VideoCompositor.Implementations
alias Membrane.VideoCompositor.Test.Support.Utility
alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
alias Membrane.VideoCompositor.Pipeline.Utility.Options

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
  Implementations.get_implementation_atom_from_string(System.get_env("IMPL", "opengl_rust"))

sink =
  case s = System.get_env("SINK", "file") do
    "file" -> out_path
    "play" -> Membrane.SDL.Player
    _unsupported -> raise "unsupported sink #{s}"
  end

src = in_path

options = %Options{
  inputs: [
    %InputStream{caps: caps, position: {0, 0}, input: src},
    %InputStream{caps: caps, position: {0, caps.height}, input: src}
  ],
  output: sink,
  caps: %RawVideo{caps | height: caps.height * 2},
  implementation: implementation
}

{:ok, pid} = Membrane.VideoCompositor.Demo.Support.Pipeline.Raw.start(options)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
