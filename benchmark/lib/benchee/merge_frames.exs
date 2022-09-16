defmodule Membrane.VideoCompositor.Benchmark.MergeFrames do
  @moduledoc """
  Benchmark for merge frames function.
  """
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Test.Support.Utility

  @spec benchmark() :: :ok
  def benchmark() do
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

    frames_720p = %{
      first: frame_720p,
      second: frame_720p
    }

    frames_1080p = %{
      first: frame_1080p,
      second: frame_1080p
    }

    frames_4k = %{
      first: frame_4k,
      second: frame_4k
    }

    {:ok, opengl_rust_internal_state_720p} = Membrane.VideoCompositor.Implementations.OpenGL.Rust.init(caps_720p)
    {:ok, opengl_rust_internal_state_1080p} = Membrane.VideoCompositor.Implementations.OpenGL.Rust.init(caps_1080p)
    {:ok, opengl_rust_internal_state_4k} = Membrane.VideoCompositor.Implementations.OpenGL.Rust.init(caps_4k)

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

    Benchee.run(
      %{
        "OpenGL Rust - Merge two frames to one" =>
          fn {frames, internal_states} -> Membrane.VideoCompositor.Implementations.OpenGL.Rust.merge_frames(frames, internal_states.opengl_rust) end,
      },
      inputs: %{
        "1. 720p" => {frames_720p, internal_states_720p},
        "2. 1080p" => {frames_1080p, internal_states_1080p},
        "3. 4k" => {frames_4k, internal_states_4k}
      },
      title: "Merge frames benchmark",
      parallel: 1,
      warmup: 2,
      time: 30,
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

Membrane.VideoCompositor.Benchmark.MergeFrames.benchmark()
