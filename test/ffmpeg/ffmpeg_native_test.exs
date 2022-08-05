defmodule VideoCompositor.FFmpeg.Native.Test do
  use ExUnit.Case, async: true

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.FFmpeg.Native
  alias Membrane.VideoCompositor.Test.Utility

  @tag :tmp_dir
  test "compose doubled raw video frames on top of each other", %{tmp_dir: tmp_dir} do
    {in_path, out_path, ref_path} = Utility.prepare_paths("1frame.yuv", "ref-native.yuv", tmp_dir)

    video = %RawVideo{
      width: 640,
      height: 360,
      pixel_format: :I420,
      framerate: {1, 1},
      aligned: nil
    }

    n_frames = 2
    assert compose_n_frames(in_path, out_path, video, n_frames)

    reference_input_path = String.replace_suffix(in_path, "yuv", "h264")

    Utility.create_ffmpeg_reference(
      reference_input_path,
      ref_path,
      "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
    )

    Utility.compare_contents(out_path, ref_path)
  end

  @tag :tmp_dir
  test "compose multiple raw video frames", %{tmp_dir: tmp_dir} do
    {in_path, out_path, _ref_path} =
      Utility.prepare_paths("1frame.yuv", "ref-native.yuv", tmp_dir)

    video = %RawVideo{
      width: 640,
      height: 360,
      pixel_format: :I420,
      framerate: {1, 1},
      aligned: nil
    }

    n_frames = 6
    assert compose_n_frames(in_path, out_path, video, n_frames)
  end

  defp compose_n_frames(in_path, out_path, caps, n_frames) do
    assert frame = File.read!(in_path)
    frames = for _n <- 1..n_frames, do: frame

    video = Membrane.VideoCompositor.FFmpeg.Native.RawVideo.from_membrane_raw_video(caps)
    videos = for _n <- 1..n_frames, do: video

    assert {:ok, ref} = Native.init(videos)
    assert {:ok, out_frame} = Native.apply_filter(frames, ref)

    assert {:ok, file} = File.open(out_path, [:write])
    on_exit(fn -> File.close(file) end)

    IO.binwrite(file, out_frame)
  end
end
