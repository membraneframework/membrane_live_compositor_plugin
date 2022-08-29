defmodule Membrane.VideoCompositor.Benchmark.RunBenchmarks do
  @moduledoc """
  Module implements functions for running benchmark.
  """

  def run_benchee_benchmarks() do
    {h264_pipeline_result, h264_pipeline_exit_code} = System.cmd(
      "mix",
      ["run", "lib/benchee/h264_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(h264_pipeline_result)

    {raw_pipeline_result, raw_pipeline_exit_code} = System.cmd(
      "mix",
      ["run", "lib/benchee/raw_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(raw_pipeline_result)

    {merge_frames_result, merge_frames_exit_code} = System.cmd(
      "mix",
      ["run", "lib/benchee/merge_frames.exs"],
      stderr_to_stdout: true
    )
    IO.puts(merge_frames_result)

    case {h264_pipeline_exit_code, raw_pipeline_exit_code, merge_frames_exit_code} do
      {0, 0, 0} ->
        :ok
      _other ->
        :error
    end
  end

  def run_beamchmark_benchmarks() do
    {h264_pipeline_result, h264_pipeline_exit_code} = System.cmd(
      "mix",
      ["run", "lib/beamchmark/h264_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(h264_pipeline_result)

    {raw_pipeline_result, raw_pipeline_exit_code} = System.cmd(
      "mix",
      ["run", "lib/beamchmark/raw_pipeline.exs"],
      stderr_to_stdout: true
    )
    IO.puts(raw_pipeline_result)

    case {h264_pipeline_exit_code, raw_pipeline_exit_code} do
      {0, 0} ->
        :ok
      _other ->
        :error
    end
  end
end

benchmark_type = System.argv()

alias Membrane.VideoCompositor.Benchmark.RunBenchmarks

require Membrane.Logger

case benchmark_type do
  ["benchee"] ->
    Membrane.Logger.info("Starting benchee benchmarks")
    RunBenchmarks.run_benchee_benchmarks
  ["beamchmark"] ->
    Membrane.Logger.info("Starting beamchmark benchmarks")
    RunBenchmarks.run_beamchmark_benchmarks
  _other ->
    Membrane.Logger.info("Starting all benchmarks")
    benchee_exit_status = RunBenchmarks.run_benchee_benchmarks
    beamchmark_exit_status = RunBenchmarks.run_beamchmark_benchmarks

    case {benchee_exit_status, beamchmark_exit_status} do
      {:ok, :ok} ->
        :ok
      _other ->
        :error
    end
end
