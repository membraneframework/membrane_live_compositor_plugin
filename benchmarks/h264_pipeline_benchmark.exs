defmodule H264PipelineBenchmark do
  @moduledoc """
  H264 pipeline benchmark.
  """

  @behaviour Beamchmark.Scenario

  @impl true
  def run() do
    h264_video_path = "./test/fixtures/long_videos/input_30s_720p.h264"
    output_path = "./test/fixtures/tmp_dir/output_10s_1280x1440_1fps.h264"

    caps = %Membrane.RawVideo{
      width: 1280,
      height: 720,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: nil
    }

    pipeline_init_options_nx = %{
      paths: %{
        first_h264_video_path: h264_video_path,
        second_h264_video_path: h264_video_path,
        output_path: output_path
      },
      caps: caps,
      implementation: :nx,
      return_pid: self()
    }

    1..10
    |> Stream.cycle()
    |> Stream.each(fn _i -> run_h264_pipeline(pipeline_init_options_nx) end)
  end

  defp run_h264_pipeline(pipeline_init_options) do
    {:ok, _pid} = Membrane.VideoCompositor.PipelineH264.start(pipeline_init_options)

    receive do
      :finished -> :ok
    end
  end
end

Beamchmark.run(H264PipelineBenchmark,
name: "H264 Pipeline Benchmark",
duration: 60,
cpu_interval: 1000,
memory_interval: 1000,
delay: 0,
compare?: false,
output_dir: "./benchmarks/results/h264_pipeline_benchmark_results",
formatters: [
  Beamchmark.Formatters.Console,
  {Beamchmark.Formatters.HTML, [output_path: "./benchmarks/results/h264_pipeline_benchmark_results"]}
]
