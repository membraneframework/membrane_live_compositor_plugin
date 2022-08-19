defmodule Membrane.VideoCompositor.Benchmark.MergeFrames do
  @moduledoc """
  Benchmark for merge frames function.
  """
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Test.Utility

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
      aligned: nil
    }

    caps_1080p = %RawVideo{
      width: 1920,
      height: 1080,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: nil
    }

    caps_4k = %RawVideo{
      width: 3840,
      height: 2160,
      framerate: {1, 1},
      pixel_format: :I420,
      aligned: nil
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

    {:ok, ffmpeg_internal_state_720p} = Membrane.VideoCompositor.FFMPEG.init(caps_720p)
    {:ok, ffmpeg_internal_state_1080p} = Membrane.VideoCompositor.FFMPEG.init(caps_1080p)
    {:ok, ffmpeg_internal_state_4k} = Membrane.VideoCompositor.FFMPEG.init(caps_4k)

    {:ok, opengl_internal_state_720p} = Membrane.VideoCompositor.OpenGL.init(caps_720p)
    {:ok, opengl_internal_state_1080p} = Membrane.VideoCompositor.OpenGL.init(caps_1080p)
    {:ok, opengl_internal_state_4k} = Membrane.VideoCompositor.OpenGL.init(caps_4k)

    {:ok, nx_internal_state_720p} = Membrane.VideoCompositor.Nx.init(caps_720p)
    {:ok, nx_internal_state_1080p} = Membrane.VideoCompositor.Nx.init(caps_1080p)
    {:ok, nx_internal_state_4k} = Membrane.VideoCompositor.Nx.init(caps_4k)

    internal_states_720p = %{
      ffmpeg: ffmpeg_internal_state_720p,
      opengl: opengl_internal_state_720p,
      nx: nx_internal_state_720p
    }

    internal_states_1080p = %{
      ffmpeg: ffmpeg_internal_state_1080p,
      opengl: opengl_internal_state_1080p,
      nx: nx_internal_state_1080p
    }

    internal_states_4k = %{
      ffmpeg: ffmpeg_internal_state_4k,
      opengl: opengl_internal_state_4k,
      nx: nx_internal_state_4k
    }

    Benchee.run(
      %{
        "Merge two frames to one - FFmpeg" =>
          fn {frames, internal_states} -> Membrane.VideoCompositor.FFMPEG.merge_frames(frames, internal_states.ffmpeg) end,
        "Merge two frames to one - OpenGL" =>
          fn {frames, internal_states} -> Membrane.VideoCompositor.OpenGL.merge_frames(frames, internal_states.opengl) end,
        "Merge two frames to one - Nx" =>
          fn {frames, internal_states} -> Membrane.VideoCompositor.Nx.merge_frames(frames, internal_states.nx) end
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
