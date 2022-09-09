defmodule VideoCompositor.OpenGL.Rust.Test do
  use ExUnit.Case, async: false

  alias Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust
  alias Membrane.VideoCompositor.Testing.Utility

  describe "OpenGL rust native test on " do
    @describetag :tmp_dir
    @describetag opengl: true

    test "inits" do
      out_video = %Rust.RawVideo{width: 640, height: 720, pixel_format: :I420}

      assert {:ok, _state} = Rust.init(out_video)
    end

    @tag timeout: :infinity
    test "compose doubled raw video frame on top of each other", %{tmp_dir: tmp_dir} do
      {in_path, out_path, ref_path} = Utility.prepare_paths("1frame.yuv", tmp_dir, "native")
      assert {:ok, frame} = File.read(in_path)

      in_video = %Rust.RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420
      }

      assert {:ok, state} =
               Rust.init(%Rust.RawVideo{
                 width: 640,
                 height: 720,
                 pixel_format: :I420
               })

      assert :ok = Rust.add_video(state, 0, in_video, %Rust.Position{x: 0, y: 0})
      assert :ok = Rust.add_video(state, 1, in_video, %Rust.Position{x: 0, y: in_video.height})

      assert {:ok, out_frame} = Rust.join_frames(state, [{0, frame}, {1, frame}])
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
