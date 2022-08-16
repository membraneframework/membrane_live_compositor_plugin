defmodule Membrane.VideoCompositor.Benchmark.Beamchmark.Raw do
  defmodule FFMPEG do
    @behaviour Beamchmark.Scenario

    @impl true
    def run() do
      RawPipeline.benchmark(:ffmpeg)
    end
  end

  defmodule OpenGL do
    @behaviour Beamchmark.Scenario

    @impl true
    def run() do
      RawPipeline.benchmark(:opengl)
    end
  end

  defmodule Nx do
    @behaviour Beamchmark.Scenario

    @impl true
    def run() do
      RawPipeline.benchmark(:nx)
    end
  end
end

defmodule RawPipeline do
  @moduledoc """
  Raw pipeline benchmark.
  """

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Test.Utility

  @spec benchmark(:ffmpeg | :opengl | :nx) :: :ok
  def benchmark(implementation) do
    caps = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {30, 1},
      pixel_format: :I420,
      aligned: nil
    }

    video_duration = 30

    output_dir = "./tmp_dir"
    output_path = Path.join(output_dir, "output_#{video_duration}s_#{caps.height}p.raw")

    input_path = "./tmp_dir/input_#{video_duration}s_#{caps.height}p.raw"
    :ok = Utility.generate_testing_video(input_path, caps, video_duration)

    pipeline_init_options = %{
      paths: %{
        first_video_path: input_path,
        second_video_path: input_path,
        output_path: output_path
      },
      caps: caps,
      implementation: implementation
    }

    1..1000
    |> Stream.each(fn _i -> run_raw_pipeline(pipeline_init_options) end)
  end

  defp run_raw_pipeline(pipeline_init_options) do
    {:ok, pid} = Membrane.VideoCompositor.PipelineRaw.start(pipeline_init_options)

    Process.monitor(pid)

    receive do
      {:DOWN, _ref, :process, _pid, :normal} -> :ok
    end
  end
end

benchmarks_options = %{
  benchmark_duration: 60,
  cpu_interval: 1000,
  memory_interval: 1000,
  delay: 0,
  compare?: false,
  output_dir: "./results/beamchmark/raw_pipeline_results",
}

Beamchmark.run(Membrane.VideoCompositor.Benchmark.Beamchmark.Raw.FFMPEG,
  name: "Raw Pipeline Benchmark - ffmpeg",
  duration: benchmarks_options.benchmark_duration,
  cpu_interval: benchmarks_options.cpu_interval,
  memory_interval: benchmarks_options.memory_interval,
  delay: benchmarks_options.delay,
  compare?: benchmarks_options.compare?,
  output_dir: benchmarks_options.output_dir,
  formatters: [
    Beamchmark.Formatters.Console,
    {Beamchmark.Formatters.HTML,
      [output_path: Path.join(benchmarks_options.output_dir, "raw_pipeline_ffmpeg_beamchmark_results.html")]}
  ]
)

Beamchmark.run(Membrane.VideoCompositor.Benchmark.Beamchmark.Raw.OpenGL,
  name: "Raw Pipeline Benchmark - OpenGL",
  duration: benchmarks_options.benchmark_duration,
  cpu_interval: benchmarks_options.cpu_interval,
  memory_interval: benchmarks_options.memory_interval,
  delay: benchmarks_options.delay,
  compare?: benchmarks_options.compare?,
  output_dir: benchmarks_options.output_dir,
  formatters: [
    Beamchmark.Formatters.Console,
    {Beamchmark.Formatters.HTML,
      [output_path: Path.join(benchmarks_options.output_dir, "raw_pipeline_opengl_beamchmark_results.html")]}
  ]
)

Beamchmark.run(Membrane.VideoCompositor.Benchmark.Beamchmark.Raw.Nx,
  name: "Raw Pipeline Benchmark - Nx",
  duration: benchmarks_options.benchmark_duration,
  cpu_interval: benchmarks_options.cpu_interval,
  memory_interval: benchmarks_options.memory_interval,
  delay: benchmarks_options.delay,
  compare?: benchmarks_options.compare?,
  output_dir: benchmarks_options.output_dir,
  formatters: [
    Beamchmark.Formatters.Console,
    {Beamchmark.Formatters.HTML,
      [output_path: Path.join(benchmarks_options.output_dir, "raw_pipeline_nx_beamchmark_results.html")]}
  ]
)
