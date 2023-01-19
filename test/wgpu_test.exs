defmodule Membrane.VideoCompositor.Test.Wgpu do
  use ExUnit.Case, async: false

  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.RustStructs.{BaseVideoPlacement, RawVideo}
  alias Membrane.VideoCompositor.Test.Support.Utils
  alias Membrane.VideoCompositor.Wgpu.Native

  describe "wgpu" do
    @describetag :tmp_dir

    @tag wgpu: true
    test "init" do
      out_video = %RawVideo{width: 640, height: 720, pixel_format: :I420, framerate: {60, 1}}

      assert {:ok, _state} = Native.init(out_video)
    end

    @tag wgpu: true
    test "simple compose", %{tmp_dir: tmp_dir} do
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
               Native.add_video(
                 state,
                 0,
                 in_video,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {in_video.width, in_video.height}
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      assert :ok =
               Native.add_video(
                 state,
                 1,
                 in_video,
                 %BaseVideoPlacement{
                   position: {0, 360},
                   size: {in_video.width, in_video.height}
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

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
    test "z value", %{tmp_dir: tmp_dir} do
      {in_path, out_path, _ref_path} = Utils.prepare_paths("1frame.yuv", tmp_dir, "native")

      assert {:ok, frame} = File.read(in_path)

      stream_format = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420,
        framerate: {60, 1}
      }

      assert {:ok, state} = Native.init(stream_format)

      assert :ok =
               Native.add_video(
                 state,
                 0,
                 stream_format,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {stream_format.width, stream_format.height},
                   z_value: 0.0
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      assert :ok =
               Native.add_video(
                 state,
                 1,
                 stream_format,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {stream_format.width, stream_format.height},
                   z_value: 0.5
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      s = bit_size(frame)
      empty_frame = <<0::size(s)>>

      assert :ok = Native.upload_frame(state, 0, empty_frame, 1)
      assert {:ok, {out_frame, 1}} = Native.upload_frame(state, 1, frame, 1)

      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      Utils.compare_contents_with_error(in_path, out_path)
    end

    @tag wgpu: true
    test "update placement", %{tmp_dir: tmp_dir} do
      {in_path, out_path, _ref_path} = Utils.prepare_paths("1frame.yuv", tmp_dir, "native")

      assert {:ok, frame} = File.read(in_path)

      stream_format = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420,
        framerate: {1, 1}
      }

      assert {:ok, state} = Native.init(stream_format)

      assert :ok =
               Native.add_video(
                 state,
                 0,
                 stream_format,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {stream_format.width, stream_format.height},
                   z_value: 0.0
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      assert :ok =
               Native.add_video(
                 state,
                 1,
                 stream_format,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {stream_format.width, stream_format.height},
                   z_value: 0.5
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      s = bit_size(frame)
      empty_frame = <<0::size(s)>>

      assert :ok = Native.upload_frame(state, 0, empty_frame, 1)
      assert {:ok, {out_frame, 1}} = Native.upload_frame(state, 1, frame, 1)

      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      Utils.compare_contents_with_error(in_path, out_path)

      Native.update_placement(state, 0, %BaseVideoPlacement{
        position: {0, 0},
        size: {stream_format.width, stream_format.height},
        z_value: 1.0
      })

      second = Membrane.Time.second()
      assert :ok = Native.upload_frame(state, 0, frame, second)
      assert {:ok, {out_frame, ^second}} = Native.upload_frame(state, 1, empty_frame, second)

      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      Utils.compare_contents_with_error(in_path, out_path)
    end

    @tag wgpu: true
    test "update transformations has correct return type" do
      stream_format = %RawVideo{
        width: 640,
        height: 360,
        pixel_format: :I420,
        framerate: {1, 1}
      }

      assert {:ok, state} = Native.init(stream_format)

      assert :ok =
               Native.add_video(
                 state,
                 0,
                 stream_format,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {stream_format.width, stream_format.height},
                   z_value: 0.0
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      assert :ok =
               Native.add_video(
                 state,
                 1,
                 stream_format,
                 %BaseVideoPlacement{
                   position: {0, 0},
                   size: {stream_format.width, stream_format.height},
                   z_value: 0.5
                 },
                 %VideoTransformations{
                   texture_transformations: []
                 }
               )

      assert :ok =
               Native.update_transformations(
                 state,
                 0,
                 %Membrane.VideoCompositor.VideoTransformations{texture_transformations: []}
               )

      bad_index = 3

      assert {:error, {:bad_video_index, ^bad_index}} =
               Native.update_transformations(
                 state,
                 bad_index,
                 %Membrane.VideoCompositor.VideoTransformations{texture_transformations: []}
               )
    end
  end
end
