alias Membrane.VideoCompositor.Examples.DynamicOutputs.Pipeline, as: DynamicOutputsPipeline

Membrane.VideoCompositor.Examples.Utils.FFmpeg.generate_sample_video()

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(DynamicOutputsPipeline, %{sample_path: "samples/testsrc.h264"})

Process.sleep(:infinity)
