alias Membrane.VideoCompositor.Examples.Transition.Pipeline

Membrane.VideoCompositor.Examples.FFmpeg.generate_sample_video()

{:ok, _supervisor, _pid} = Pipeline.start_link(%{sample_path: "samples/testsrc.h264"})

Process.sleep(:infinity)
