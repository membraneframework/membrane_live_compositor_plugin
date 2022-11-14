# Benchmarks for Membrane Video Compositor Plugin

## Current benchmarks

1. Benchee (run time and memory usage benchmarks):
    - h264 pipeline benchmark `lib\benchee\h264_pipeline.exs`
    - raw pipeline benchmark `lib\benchee\raw_pipeline.exs`
## How to run benchmarks:

1.  Enter benchmark folder `cd benchmark`
2.  Run `mix deps.get` command
3.  Run command for benchmarks:
    1. For running packs of benchee benchmarks: `mix run benchmark.exs [<merges_per_iteration>]` </br>
        (Default number of merges is 60 per iteration.)
    2. For running single benchmarks:
        - for measuring raw pipeline performance: `mix run lib/benchee/raw_pipeline.exs`
        - for measuring h264 pipeline performance: `mix run lib/benchee/h264_pipeline.exs [<merges_per_iteration>]` </br>
        (Default number of merges is 60 per iteration.)
4. Results will be displayed in console log and saved in html website saved at "results" directory

## How to modify test length:

- Modify parameters in `Benchee.run()` function:
    - `warmup` for time of benchmark warmup
    - `time` for time of pipeline performance measurement
    - `memory_time` for time of pipeline memory usage measurement
