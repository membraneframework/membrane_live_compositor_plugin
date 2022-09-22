require Membrane.Logger
alias Membrane.VideoCompositor.Benchmark.RunBenchmarks


defmodule Membrane.VideoCompositor.Benchmark.RunBenchmarks do
  @moduledoc """
  Module implements functions for running benchmark.
  """

  @spec run_benchee_benchmarks(integer()) :: :ok | :error
  def run_benchee_benchmarks(merges_per_iteration) do
    Membrane.Logger.info("Starting benchee benchmarks - #{merges_per_iteration} merges per iteration in merge frames benchmark")

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
      ["run", "lib/benchee/merge_frames.exs", "#{merges_per_iteration}"],
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
end

benchmark_options = System.argv()
default_merges_per_iteration = 60

case benchmark_options do
  [merges_per_iteration] ->
    RunBenchmarks.run_benchee_benchmarks(merges_per_iteration)
  _other ->
    RunBenchmarks.run_benchee_benchmarks(default_merges_per_iteration)
end
