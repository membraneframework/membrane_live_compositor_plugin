alias Membrane.VideoCompositor.Examples.Transition.Pipeline, as: TransitionPipeline

Membrane.VideoCompositor.Examples.Utils.FFmpeg.generate_sample_video()

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(TransitionPipeline, %{sample_path: "samples/testsrc.h264"})

Process.sleep(:infinity)
