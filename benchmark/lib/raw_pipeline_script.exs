alias Membrane.RawVideo
alias Membrane.VideoCompositor.Benchmark.Support.Utility
alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
alias Membrane.VideoCompositor.Pipeline.Utility.Options

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

video_duration = 60

basename = Utility.get_file_base_name(caps, video_duration, "raw")
demo_path = Path.join([File.cwd!(), "lib", "tmp", "fixtures"])
in_path = Path.join(demo_path, "in-#{basename}")
out_path = Path.join(demo_path, "out-#{basename}")

Utility.generate_testing_video(in_path, caps, video_duration)

sink =
  case s = System.get_env("SINK", "file") do
    "file" -> out_path
    "play" -> Membrane.SDL.Player
    _unsupported -> raise "unsupported sink #{s}"
  end

src = in_path

options = %Options{
  inputs: [
    %InputStream{
      position: {0, 0},
      z_value: 0.0,
      scale: 1.0,
      caps: caps,
      input: src
    },
    %InputStream{
      position: {0, caps.height},
      z_value: 0.0,
      scale: 1.0,
      caps: caps,
      input: src
    },
    %InputStream{
      position: {caps.width, 0},
      z_value: 0.0,
      scale: 1.0,
      caps: caps,
      input: src
    },
    %InputStream{
      position: {caps.width, caps.height},
      z_value: 0.0,
      scale: 1.0,
      caps: caps,
      input: src
    }
  ],
  output: sink,
  caps: %RawVideo{caps | width: caps.width * 2, height: caps.height * 2},
}

{:ok, pid} = Membrane.VideoCompositor.Benchmark.Support.Pipeline.Raw.start(options)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
