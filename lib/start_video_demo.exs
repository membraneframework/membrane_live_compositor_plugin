input_path = "testsrc.raw"
output_path = "output.h264"
{:ok, pid} = Membrane.VideoCompositor.Pipeline.start([input_path, output_path])
Membrane.VideoCompositor.Pipeline.play(pid)
