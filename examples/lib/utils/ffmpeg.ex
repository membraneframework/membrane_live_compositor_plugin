defmodule Utils.FFmpeg do
  @moduledoc false

  @spec generate_sample_video() :: nil
  def generate_sample_video() do
    unless File.exists?("samples/testsrc.h264") do
      IO.puts("Creating sample video")
      File.mkdir_p!("samples")

      {_, 0} =
        System.cmd("ffmpeg", [
          "-y",
          "-f",
          "lavfi",
          "-i",
          "testsrc=duration=90:size=1280x720:rate=30",
          "-pix_fmt",
          "yuv420p",
          "samples/testsrc.h264"
        ])
    end

    unless File.exists?("samples/test.ogg") do
      sample_url = "https://getsamplefiles.com/download/opus/sample-1.opus"
      IO.puts("Downloading audio sample from #{sample_url}")
      File.mkdir_p!("samples")

      {_, 0} =
        System.cmd("curl", ["-L", sample_url, "-o", "samples/test.ogg"])
    end

    unless File.exists?("samples/test.mp4") do
      sample_url =
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

      IO.puts("Downloading MP4 sample from #{sample_url}")
      File.mkdir_p!("samples")

      {_, 0} =
        System.cmd("curl", ["-L", sample_url, "-o", "samples/test.mp4"])
    end
  end
end
