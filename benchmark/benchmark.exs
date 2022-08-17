defmodule Membrane.VideoCompositor.Benchmark.RunBenchmarks do
  @moduledoc """
  Module implements functions for running benchmark.
  """

  def run_benchee_benchmarks() do
    {benchee_h264_result, _exit_code} = System.cmd(
      "mix",
      ["run", "lib/benchee/h264_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(benchee_h264_result)

    {benchee_raw_result, _exit_code} = System.cmd(
      "mix",
      ["run", "lib/benchee/raw_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(benchee_raw_result)

    {benchee_merge_frames_result, _exit_code} = System.cmd(
      "mix",
      ["run", "lib/benchee/merge_frames.exs"],
      stderr_to_stdout: true
    )
    IO.puts(benchee_merge_frames_result)
  end

  def run_beamchmark_benchmarks() do
    {beamchmark_h264_result, _exit_code} = System.cmd(
      "mix",
      ["run", "lib/beamchmark/h264_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(beamchmark_h264_result)

    {beamchmark_raw_result, _exit_code} = System.cmd(
      "mix",
      ["run", "lib/beamchmark/raw_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(beamchmark_raw_result)
  end
end

benchmark_type = System.argv()

alias Membrane.VideoCompositor.Benchmark.RunBenchmarks

case benchmark_type do
  ["benchee"] ->
    RunBenchmarks.run_benchee_benchmarks
  ["beamchmark"] ->
    RunBenchmarks.run_beamchmark_benchmarks
  _other ->
    RunBenchmarks.run_benchee_benchmarks
    RunBenchmarks.run_beamchmark_benchmarks
end
