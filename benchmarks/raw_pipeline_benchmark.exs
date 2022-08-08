defmodule RawPipelineBenchmark do
  @moduledoc """
  Raw pipeline benchmark.
  """

  @behaviour Beamchmark.Scenario

  @impl true
  def run() do
    raw_video_path = "./test/fixtures/long_videos/input_10s_720p_1fps.raw"
    output_path = "./test/fixtures/tmp_dir/output_10s_1280x1440_1fps.raw"

    caps = %Membrane.RawVideo{
      width: 1280,
      height: 720,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: nil
    }

    pipeline_init_options_nx = %{
      paths: %{
        first_raw_video_path: raw_video_path,
        second_raw_video_path: raw_video_path,
        output_path: output_path
      },
      caps: caps,
      implementation: :nx,
      return_pid: self()
    }

    1..10
    |> Stream.cycle()
    |> Stream.each(fn _i -> run_raw_pipeline(pipeline_init_options_nx) end)
  end

  defp run_raw_pipeline(pipeline_init_options) do
    {:ok, _pid} = Membrane.VideoCompositor.PipelineRaw.start(pipeline_init_options)

    receive do
      :finished -> :ok
    end
  end
end

Beamchmark.run(RawPipelineBenchmark,
  name: "Raw Pipeline Benchmark",
  duration: 60,
  cpu_interval: 1000,
  memory_interval: 1000,
  delay: 0,
  compare?: false,
  output_dir: "./benchmarks/results/raw_pipeline_benchmark_results",
  formatters: [
    Beamchmark.Formatters.Console,
    {Beamchmark.Formatters.HTML, [output_path: "./benchmarks/results/raw_pipeline_benchmark_results"]}
  ]
)
