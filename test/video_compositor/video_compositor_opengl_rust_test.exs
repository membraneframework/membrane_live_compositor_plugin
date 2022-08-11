defmodule VideoCompositor.OpenGL.Rust.Test do
  use ExUnit.Case, async: false

  alias Membrane.VideoCompositor.OpenGL.Rust
  alias Membrane.VideoCompositor.Test.Utility

  test "inits" do
    first_video = %Rust.RawVideo{ width: 640, height: 360, pixel_format: :I420 }
    second_video = %Rust.RawVideo{ width: 640, height: 360, pixel_format: :I420 }
    out_video = %Rust.RawVideo{ width: 640, height: 720, pixel_format: :I420 }

    assert {:ok, state} = Rust.init(first_video, second_video, out_video)
  end

  @tag :tmp_dir
  @tag timeout: :infinity
  test "compose doubled raw video frame on top of each other", %{tmp_dir: tmp_dir} do
    {in_path, out_path, ref_path} = Utility.prepare_paths("1frame.yuv", "ref-native.yuv", tmp_dir)
    assert {:ok, frame_a} = File.read(in_path)
    assert {:ok, frame_b} = File.read(in_path)

    assert {:ok, state} =
             Rust.init(
               %Rust.RawVideo{
                 width: 640,
                 height: 360,
                 pixel_format: :I420,
               },
               %Rust.RawVideo{
                 width: 640,
                 height: 360,
                 pixel_format: :I420,
               },
               %Rust.RawVideo{
                width: 640,
                height: 720,
                pixel_format: :I420,
              }
             )

    assert {:ok, out_frame} = Rust.join_frames(state, frame_a, frame_b)
    assert {:ok, file} = File.open(out_path, [:write])
    on_exit(fn -> File.close(file) end)

    IO.binwrite(file, out_frame)
    reference_input_path = "../fixtures/1frame.h264" |> Path.expand(__DIR__)

    Utility.create_ffmpeg_reference(
      reference_input_path,
      ref_path,
      "split[b], pad=iw:ih*2[src], [src][b]overlay=0:h"
    )

    Utility.compare_contents(out_path, ref_path)
  end
end
