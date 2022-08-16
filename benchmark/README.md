# Benchmarks for Membrane Video Compositor Plugin

## How to run benchmarks:

1.  Enter benchmark folder (cd benchmark)
2.  Run "mix deps.get" command
3.  Run command for benchmarks:
    - benchee benchmarks (run time and memory usage benchmarks): 
        - for measuring frame composition performance: "mix run lib/benchee/merge_frames.exs"
        - for measuring raw pipeline performance: "mix run lib/benchee/raw_pipeline.exs"
        - for measuring h264 pipeline performance: "mix run lib/benchee/h264_pipeline.exs"
    - beamchmark benchmarks (reductions / contex switches / cpu and memory usage / schedulers)
        - for measuring raw pipeline performance: "mix run lib/beamchmark/raw_pipeline.exs"
        - for measuring h264 pipeline performance: "mix run lib/beamchmark/h264_pipeline.exs"
4. Results will be displayed in console log and saved in html website saved at "results" directory

## Example benchmarks results:
<img src="benchmark/assets/results_beamchmark_h264_pipeline_ffmpeg.png" alt="H264 pipeline ffmpeg" title="H264 pipeline beamchmark ffmpeg">
<img src="benchmark/assets/results_beamchmark_raw_pipeline_ffmpeg.png" alt="Raw pipeline ffmpeg" title="Raw pipeline beamchmark ffmpeg">
<img src="benchmark/assets/results_benchee_merge_frames_720p.png" alt="Merge frames benchee results" title="Merge frames benchee results">
