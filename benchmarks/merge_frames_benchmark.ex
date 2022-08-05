defmodule MergeFramesBenchmark do
  @moduledoc """
  Benchmark for merge frames function.
  """
  alias Membrane.RawVideo

  def benchmark() do
    {:ok, raw_720p_frame} = File.read("./test/fixtures/single_frames/single_raw_frame_720p.raw")
    {:ok, raw_1080p_frame} = File.read("./test/fixtures/single_frames/single_raw_frame_1080p.raw")
    {:ok, raw_4k_frame} = File.read("./test/fixtures/single_frames/single_raw_frame_4k.raw")

    frames_720p = %{
      first: raw_720p_frame,
      second: raw_720p_frame
    }

    frames_1080p = %{
      first: raw_1080p_frame,
      second: raw_1080p_frame
    }

    frames_4k = %{
      first: raw_4k_frame,
      second: raw_4k_frame
    }

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

    {:ok, nx_internal_state_720p} = Membrane.VideoCompositor.Nx.init(caps_720p)
    {:ok, nx_internal_state_1080p} = Membrane.VideoCompositor.Nx.init(caps_1080p)
    {:ok, nx_internal_state_4k} = Membrane.VideoCompositor.Nx.init(caps_4k)

    internal_states_720p = %{
      nx: nx_internal_state_720p
    }

    internal_states_1080p = %{
      nx: nx_internal_state_1080p
    }

    internal_states_4k = %{
      nx: nx_internal_state_4k
    }

    Benchee.run(
      %{
        "Merge two frames to one - Nx" =>
          fn {frames, internal_states} -> Membrane.VideoCompositor.Nx.merge_frames(frames, internal_states.nx) end
      },
      inputs: %{
        "1. 720p" => {frames_720p, internal_states_720p},
        "2. 1080p" => {frames_1080p, internal_states_1080p},
        "3. 4k" => {frames_4k, internal_states_4k}
      },
      time: 30,
      memory_time: 2
    )
  end
end
