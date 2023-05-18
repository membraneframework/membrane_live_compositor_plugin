defmodule Membrane.VideoCompositor.WgpuTest do
  use ExUnit.Case, async: false

  alias Membrane.VideoCompositor.VideoTransformations
  alias Membrane.VideoCompositor.RustStructs.{BaseVideoPlacement, RawVideo}
  alias Membrane.VideoCompositor.Scene.BaseVideoPlacement
  alias Membrane.VideoCompositor.Support.Utils
  alias Membrane.VideoCompositor.Wgpu.Native

  @stream_format_360p_1fps %RawVideo{
    width: 640,
    height: 360,
    pixel_format: :I420,
    framerate: {1, 1}
  }

  defp init_two_overlapping_videos() do
    stream_format = @stream_format_360p_1fps

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

    state
  end

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

      in_video = @stream_format_360p_1fps

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

      assert :ok = Native.process_frame(state, 0, frame, 1)
      assert {:ok, {out_frame, 1}} = Native.process_frame(state, 1, frame, 1)
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

      state = init_two_overlapping_videos()

      s = bit_size(frame)
      empty_frame = <<0::size(s)>>

      assert :ok = Native.process_frame(state, 0, empty_frame, 1)
      assert {:ok, {out_frame, 1}} = Native.process_frame(state, 1, frame, 1)

      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      Utils.compare_contents_with_error(in_path, out_path)
    end

    @tag wgpu: true
    test "update placement", %{tmp_dir: tmp_dir} do
      {in_path, out_path, _ref_path} = Utils.prepare_paths("1frame.yuv", tmp_dir, "native")

      assert {:ok, frame} = File.read(in_path)

      stream_format = @stream_format_360p_1fps
      state = init_two_overlapping_videos()

      s = bit_size(frame)
      empty_frame = <<0::size(s)>>

      assert :ok = Native.process_frame(state, 0, empty_frame, 1)
      assert {:ok, {out_frame, 1}} = Native.process_frame(state, 1, frame, 1)

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
      assert :ok = Native.process_frame(state, 0, frame, second)
      assert {:ok, {out_frame, ^second}} = Native.process_frame(state, 1, empty_frame, second)

      assert {:ok, file} = File.open(out_path, [:write])
      IO.binwrite(file, out_frame)
      File.close(file)

      Utils.compare_contents_with_error(in_path, out_path)
    end

    @tag wgpu: true
    test "update transformations has correct return type" do
      state = init_two_overlapping_videos()

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

    @tag wgpu: true
    test "handle end of stream message correctly", %{tmp_dir: tmp_dir} do
      {in_path, out_path, _ref_path} = Utils.prepare_paths("1frame.yuv", tmp_dir, "native")

      assert {:ok, frame} = File.read(in_path)

      state = init_two_overlapping_videos()

      s = bit_size(frame)
      empty_frame = <<0::size(s)>>

      frame_time = Membrane.Time.second()

      for i <- 0..2 do
        assert :ok = Native.process_frame(state, 1, empty_frame, i * frame_time)
      end

      # two frames that we upload should produce a buffer, since both vids have frames
      for i <- 0..2 do
        assert {:ok, _buffer} = Native.process_frame(state, 0, frame, i * frame_time)
      end

      # two next frames into vid 0 should not output a buffer, since there are no frames in vid 1
      for i <- 2..4 do
        assert :ok = Native.process_frame(state, 0, frame, i * frame_time)
      end

      # after end of stream, two frames in vid 0 queue are not blocked anymore and should be rendered
      # since vid 0 was in the back before, these frames should contain the reference image
      assert {:ok, buffers} = Native.send_end_of_stream(state, 1)

      assert length(buffers) == 2

      Enum.each(buffers, fn {frame, _pts} ->
        assert {:ok, file} = File.open(out_path, [:write])
        IO.binwrite(file, frame)
        File.close(file)

        Utils.compare_contents_with_error(in_path, out_path)
      end)
    end
  end
end
