alias Membrane.VideoCompositor.Examples.Transition.Pipeline

unless File.exists?("samples/testsrc.h264") do
  {_, 0} =
    System.cmd("ffmpeg", [
      "-y",
      "-f",
      "lavfi",
      "-i",
      "testsrc=duration=30:size=1280x720:rate=30",
      "-pix_fmt",
      "yuv420p",
      "samples/testsrc.h264"
    ])
end

{:ok, _supervisor, _pid} = Pipeline.start_link(%{})

:timer.sleep(100_000)
