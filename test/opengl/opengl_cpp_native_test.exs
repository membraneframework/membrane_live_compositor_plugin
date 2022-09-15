defmodule VideoCompositor.OpenGL.Cpp.Native.Test do
  use ExUnit.Case

  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Implementations.OpenGL.Native.Cpp
  alias Membrane.VideoCompositor.Utility

  describe "OpenGL cpp native test on " do
    @describetag :tmp_dir
    @describetag opengl: true

    test "compose doubled raw video frames on top of each other", %{tmp_dir: tmp_dir} do
      {in_path, out_path, ref_path} = Utility.prepare_paths("1frame.yuv", tmp_dir, "native")

      video = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420,
        framerate: {1, 1},
        aligned: nil
      }

      {:ok, video} =
        Membrane.VideoCompositor.Implementations.FFmpeg.Native.RawVideo.from_membrane_raw_video(
          video
        )

      assert in_frame = File.read!(in_path)

      assert {:ok, state} = Cpp.init(video, video)
      assert {:ok, out_frame} = Cpp.join_frames(in_frame, in_frame, state)
      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(out_path)

      ref_in_path = String.replace_suffix(in_path, "yuv", "h264")

      Utility.generate_ffmpeg_reference(
        ref_in_path,
        ref_path,
        "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
      )

      Utility.compare_contents(out_path, ref_path)
    end
  end
end
