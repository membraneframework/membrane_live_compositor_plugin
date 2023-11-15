alias Membrane.VideoCompositor.Examples.LayoutWithShader.Pipeline

Membrane.VideoCompositor.Examples.Utils.FFmpeg.generate_sample_video()

{:ok, _supervisor, _pid} = Pipeline.start_link(%{sample_path: "samples/testsrc.h264"})

Process.sleep(:infinity)
