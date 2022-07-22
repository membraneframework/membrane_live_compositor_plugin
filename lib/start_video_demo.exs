# ex ~/membrane_demo/nx_composer_demo/testsrc.raw
first_video_path = "add here first video path"
# ex ~/membrane_demo/nx_composer_demo/testsrc.raw
second_video_path = "add here second video path"
# ex output.h264
output_path = "output path"
{:ok, pid} = SimpleComposerDemo.Pipeline.start([first_video_path, second_video_path, output_path])
SimpleComposerDemo.Pipeline.play(pid)
Process.sleep(1000)
