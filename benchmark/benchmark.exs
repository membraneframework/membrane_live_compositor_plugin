require Membrane.Logger
alias Membrane.VideoCompositor.Benchmark.RunBenchmarks


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
end

Membrane.Logger.info("Starting benchee benchmarks")
RunBenchmarks.run_benchee_benchmarks
