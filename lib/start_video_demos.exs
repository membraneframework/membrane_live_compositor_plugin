first_video_path = "testsrc.raw"
second_video_path = "testsrc.raw"
output_path = "output.h264"  # ex output.h264
implementation = :nx
{:ok, pid} = Membrane.VideoCompositor.Pipeline.start([%{first_raw_video_path})
Membrane.VideoCompositor.Pipeline.play(pid)
Process.sleep(10000)
