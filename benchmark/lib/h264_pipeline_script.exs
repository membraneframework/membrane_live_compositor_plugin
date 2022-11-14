require Logger
alias Membrane.RawVideo
alias Membrane.VideoCompositor.Benchmark.Support.Utility
alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
alias Membrane.VideoCompositor.Pipeline.Utility.Options

caps = %RawVideo{
  aligned: true,
  framerate: {60, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

video_duration = 120

basename = Utility.get_file_base_name(caps, video_duration, "h264")
demo_path = Path.join([File.cwd!(), "lib", "tmp", "fixtures"])
in_path = Path.join(demo_path, "in-#{basename}")
out_path = Path.join(demo_path, "out-#{basename}")

Utility.generate_testing_video(in_path, caps, video_duration)

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
  output: out_path,
  caps: %RawVideo{caps | width: caps.width * 2, height: caps.height * 2},
}

Logger.info("Starting benchmark")
{:ok, pid} = Membrane.VideoCompositor.Benchmark.Support.Pipeline.H264.start(options)


Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
