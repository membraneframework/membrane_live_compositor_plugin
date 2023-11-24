alias Membrane.VideoCompositor.Examples.LayoutWithShader.Pipeline, as: LayoutWithShaderPipeline

Membrane.VideoCompositor.Examples.Utils.FFmpeg.generate_sample_video()

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(LayoutWithShaderPipeline, %{sample_path: "samples/testsrc.h264"})

Process.sleep(:infinity)
