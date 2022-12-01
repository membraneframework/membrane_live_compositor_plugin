defmodule VideoCompositor.Wgpu.Test do
  use ExUnit.Case, async: false

  alias Membrane.VideoCompositor.RustStructs.{RawVideo, VideoLayout}
  alias Membrane.VideoCompositor.Test.Support.Utils
  alias Membrane.VideoCompositor.Wgpu.Native

  describe "wgpu native test on" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "inits" do
      out_video = %RawVideo{width: 640, height: 720, pixel_format: :I420, framerate: {60, 1}}

      assert {:ok, _state} = Native.init(out_video)
    end

    @tag wgpu: true
    test "compose doubled raw video frame on top of each other", %{tmp_dir: tmp_dir} do
      {in_path, out_path, ref_path} = Utils.prepare_paths("1frame.yuv", tmp_dir, "native")

      assert {:ok, frame} = File.read(in_path)

      in_video = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420,
        framerate: {60, 1}
      }

      assert {:ok, state} =
               Native.init(%RawVideo{
                 width: 640,
                 height: 720,
                 pixel_format: :I420,
                 framerate: {60, 1}
               })

      assert :ok =
               Native.add_video(state, 0, in_video, %VideoLayout{
                 position: {0, 0},
                 display_size: {in_video.width, in_video.height}
               })

      assert :ok =
               Native.add_video(state, 1, in_video, %VideoLayout{
                 position: {0, 360},
                 display_size: {in_video.width, in_video.height}
               })

      assert :ok = Native.upload_frame(state, 0, frame, 1)
      assert {:ok, {out_frame, 1}} = Native.upload_frame(state, 1, frame, 1)
      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      reference_input_path = String.replace_suffix(in_path, "yuv", "h264")

      Utils.generate_ffmpeg_reference(
        reference_input_path,
        ref_path,
        "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
      )

      Utils.compare_contents_with_error(out_path, ref_path)
    end

    @tag wgpu: true
    test "z value affects composition", %{tmp_dir: tmp_dir} do
      {in_path, out_path, _ref_path} = Utils.prepare_paths("1frame.yuv", tmp_dir, "native")

      assert {:ok, frame} = File.read(in_path)

      caps = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420,
        framerate: {60, 1}
      }

      assert {:ok, state} = Native.init(caps)

      assert :ok =
               Native.add_video(state, 0, caps, %VideoLayout{
                 position: {0, 0},
                 display_size: {caps.width, caps.height},
                 z_value: 0.0
               })

      assert :ok =
               Native.add_video(state, 1, caps, %VideoLayout{
                 position: {0, 0},
                 display_size: {caps.width, caps.height},
                 z_value: 0.5
               })

      s = bit_size(frame)
      empty_frame = <<0::size(s)>>

      assert :ok = Native.upload_frame(state, 0, empty_frame, 1)
      assert {:ok, {out_frame, 1}} = Native.upload_frame(state, 1, frame, 1)

      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      Utils.compare_contents_with_error(in_path, out_path)
    end
  end
end
