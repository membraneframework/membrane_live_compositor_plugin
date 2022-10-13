defmodule Membrane.VideoCompositor.Test.Scene.ComposingTest do
  use ExUnit.Case

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions

  alias Membrane.H264.FFmpeg.Encoder
  alias Membrane.Testing.Pipeline
  alias Membrane.VideoCompositor.Test.Support.Utility, as: TestingUtility
  alias Membrane.{FileVideoCompositor, ParentSpec, RawVideo, VideoCompositor}
  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Test.Support.Pipeline.H264

  @filter_description "split[b], pad=iw*2:ih*2:iw/2:0[src], [src][b]overlay=w/2:h"

  describe "Video Compositor with scene" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      video_caps = %RawVideo{
        width: 1280,
        height: 720,
        pixel_format: :I420,
        framerate: {24, 1},
        aligned: true
      }

      duration = 10

      {input_path, output_path, reference_path} =
        TestingUtility.prepare_testing_video(
          video_caps,
          duration,
          "h264",
          tmp_dir,
          "short_videos"
        )

      :ok =
        TestingUtility.generate_ffmpeg_reference(
          input_path,
          reference_path,
          @filter_description
        )

      scene = [
        size: %{width: video_caps.width * 2, height: video_caps.height * 2},
        position: %Position{x: 0, y: 0},
        videos: %{
          0 => [
            position: %Position{x: video_caps.width / 2, y: 0}
          ],
          1 => [
            position: %Position{x: video_caps.width / 2, y: video_caps.height}
          ]
        }
      ]

      %{
        input_path: input_path,
        output_path: output_path,
        reference_path: reference_path,
        scene: scene,
        video_caps: video_caps
      }
    end

    test "with scene", %{
      input_path: input_path,
      output_path: output_path,
      reference_path: reference_path,
      scene: scene,
      video_caps: video_caps
    } do
      assert children = [
               compositor: %VideoCompositor{
                 implementation: :wgpu,
                 caps: %RawVideo{
                   video_caps
                   | width: video_caps.width * 2,
                     height: video_caps.height * 2
                 },
                 scene: scene
               },
               encoder: Encoder,
               sink: %File.Sink{location: output_path}
             ]

      links = [
        link(:source_0, %H264.Source{location: input_path})
        |> via_in(:input, options: [id: 0])
        |> to(:compositor),
        link(:source_1, %H264.Source{location: input_path})
        |> via_in(:input, options: [id: 1])
        |> to(:compositor),
        link(:compositor) |> to(:encoder) |> to(:sink)
      ]

      assert {:ok, pid} = Pipeline.start_link(children: children, links: links)

      assert_pipeline_playback_changed(pid, _, :playing)

      assert_end_of_stream(pid, :sink, :input, 1_000_000)

      Pipeline.terminate(pid, blocking?: true)

      assert TestingUtility.compare_contents_with_error(reference_path, output_path)
    end
  end
end
