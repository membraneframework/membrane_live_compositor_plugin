defmodule Membrane.VideoCompositor.Benchmark.Benchee.MergeFrames do
  @moduledoc """
  Benchmark for merge frames function.
  """
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Test.Support.Utility

  @spec benchmark(integer()) :: :ok
  def benchmark(merges_per_iteration) do
    report_dir = "./results/benchee/merge_frames_results"
    raw_720p_frame_path = "./tmp_dir/frame_720p.raw"
    raw_1080p_frame_path = "./tmp_dir/frame_1080p.raw"
    raw_4k_frame_path = "./tmp_dir/frame_4k.raw"

    caps_720p = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: true
    }

    caps_1080p = %RawVideo{
      width: 1920,
      height: 1080,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: true
    }

    caps_4k = %RawVideo{
      width: 3840,
      height: 2160,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: true
    }

    :ok = Utility.generate_testing_video(raw_720p_frame_path, caps_720p, 1)
    :ok = Utility.generate_testing_video(raw_1080p_frame_path, caps_1080p, 1)
    :ok = Utility.generate_testing_video(raw_4k_frame_path, caps_4k, 1)

    {:ok, frame_720p} = File.read(raw_720p_frame_path)
    {:ok, frame_1080p} = File.read(raw_1080p_frame_path)
    {:ok, frame_4k} = File.read(raw_4k_frame_path)

    frames_720p = [{0, frame_720p}, {1, frame_720p}]
    frames_1080p = [ {0, frame_1080p}, {1, frame_1080p}]
    frames_4k = [{0, frame_4k}, {1, frame_4k}]

    {:ok, opengl_rust_internal_state_720p} = Membrane.VideoCompositor.OpenGL.Rust.init(caps_720p)
    {:ok, opengl_rust_internal_state_1080p} = Membrane.VideoCompositor.OpenGL.Rust.init(caps_1080p)
    {:ok, opengl_rust_internal_state_4k} = Membrane.VideoCompositor.OpenGL.Rust.init(caps_4k)



    # FIXME: Add wgpu when it's ready
    # FIXME: Fixes like the above shouldn't be manual

    internal_states_720p = %{
      opengl_rust: opengl_rust_internal_state_720p,
    }

    internal_states_1080p = %{
      opengl_rust: opengl_rust_internal_state_1080p,
    }

    internal_states_4k = %{
      opengl_rust: opengl_rust_internal_state_4k,
    }

    Membrane.VideoCompositor.OpenGL.Rust.add_video(internal_states_720p.opengl_rust, 0, caps_720p, {0, 0})
    Membrane.VideoCompositor.OpenGL.Rust.add_video(internal_states_720p.opengl_rust, 1, caps_720p, {0, caps_720p.height})

    Membrane.VideoCompositor.OpenGL.Rust.add_video(internal_states_1080p.opengl_rust, 0, caps_1080p, {0, 0})
    Membrane.VideoCompositor.OpenGL.Rust.add_video(internal_states_1080p.opengl_rust, 1, caps_1080p, {0, caps_1080p.height})

    Membrane.VideoCompositor.OpenGL.Rust.add_video(internal_states_4k.opengl_rust, 0, caps_4k, {0, 0})
    Membrane.VideoCompositor.OpenGL.Rust.add_video(internal_states_4k.opengl_rust, 1, caps_4k, {0, caps_4k.height})

    range = 1..merges_per_iteration

    Benchee.run(
      %{
        "OpenGL Rust - Merge two frames to one - #{merges_per_iteration} merges per iteration" =>
          fn {frames, internal_states} ->
            for _ <- range, do:
              Membrane.VideoCompositor.OpenGL.Rust.merge_frames(internal_states.opengl_rust, frames)
          end
      },
      inputs: %{
        "1. 720p" => {frames_720p, internal_states_720p},
        "2. 1080p" => {frames_1080p, internal_states_1080p},
        "3. 4k" => {frames_4k, internal_states_4k}
      },
      title: "Merge frames benchmark",
      parallel: 1,
      warmup: 2,
      time: 60,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.HTML, file: Path.join(report_dir, "merge_frames_benchmark.html")},
        Benchee.Formatters.Console
      ]
    )

    File.rm(raw_720p_frame_path)
    File.rm(raw_1080p_frame_path)
    File.rm(raw_4k_frame_path)
    :ok
  end
end

benchmark_options = System.argv()
default_merges_per_iteration = 60

case benchmark_options do
  [merges_per_iteration] ->
    {merges_per_iteration, _} = Integer.parse(merges_per_iteration)
    Membrane.VideoCompositor.Benchmark.Benchee.MergeFrames.benchmark(merges_per_iteration)
  _other ->
    Membrane.VideoCompositor.Benchmark.Benchee.MergeFrames.benchmark(default_merges_per_iteration)
end
