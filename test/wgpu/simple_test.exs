defmodule VideoCompositor.Wgpu.Test do
  use ExUnit.Case, async: false

  alias Membrane.VideoCompositor.OpenGL.Native.Rust.RawVideo
  alias Membrane.VideoCompositor.Utility
  alias Membrane.VideoCompositor.Wgpu.Native

  describe "wgpu native test on " do
    @describetag :tmp_dir
    @describetag :wgpu

    test "inits" do
      in_video = %RawVideo{width: 640, height: 360, pixel_format: :I420}
      out_video = %RawVideo{width: 640, height: 720, pixel_format: :I420}

      assert {:ok, _state} = Native.init(in_video, in_video, out_video)
    end

    @tag timeout: :infinity
    test "compose doubled raw video frame on top of each other", %{tmp_dir: tmp_dir} do
      {in_path, out_path, ref_path} = Utility.prepare_paths("1frame.yuv", tmp_dir, "native")
      assert {:ok, frame} = File.read(in_path)

      in_video = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420
      }

      assert {:ok, state} =
               Native.init(
                 in_video,
                 in_video,
                 %RawVideo{
                   width: 640,
                   height: 720,
                   pixel_format: :I420
                 }
               )

      assert {:ok, out_frame} = Native.join_frames(state, frame, frame)
      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      reference_input_path = String.replace_suffix(in_path, "yuv", "h264")

      Utility.generate_ffmpeg_reference(
        reference_input_path,
        ref_path,
        "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
      )

      Utility.compare_contents(out_path, ref_path)
    end
  end
end
