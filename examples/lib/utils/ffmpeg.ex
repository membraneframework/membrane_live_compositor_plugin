defmodule Membrane.VideoCompositor.Examples.Utils.FFmpeg do
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
  end
end
