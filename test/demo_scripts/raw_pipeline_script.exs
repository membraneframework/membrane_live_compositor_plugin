alias Membrane.RawVideo

paths = %{
  first_video_path: "./test/fixtures/long_videos/input_10s_720p_1fps.raw",
  second_video_path: "./test/fixtures/long_videos/input_10s_720p_1fps.raw",
  output_path: "./test/fixtures/long_videos/composed_video_10s_1280x1440_1fps.raw"
}

caps = %RawVideo{
  aligned: true,
  framerate: {1, 1},
  width: 1280,
  height: 720,
  pixel_format: :I420
}

implementation = :nx

parser = %Membrane.RawVideo.Parser{
  framerate: caps.framerate,
  width: caps.width,
  height: caps.height,
  pixel_format: caps.pixel_format
}

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation,
  input_parser: parser
}

{:ok, pid} = Membrane.VideoCompositor.PipelineTemplate.start(options)

Process.sleep(1_000_000)
