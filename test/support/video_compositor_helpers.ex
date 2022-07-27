defmodule Membrane.VideoCompositor.Test.Utility do
  @moduledoc false
  import ExUnit.Assertions

  require Membrane.Logger

  @doc """
  Generate and save a video in the given filename.
  """
  @spec generate_testing_raw_video(binary(), Membrane.RawVideo, integer()) :: nil | :ok
  def generate_testing_raw_video(file_name, video_description, duration) do
    # ffmpeg -f lavfi -i testsrc=duration=4:size=1280x720:rate=30,format=yuv420p -f rawvideo test/fixtures/4s_30fps.raw
    video_description_str = """
    testsrc=\
    duration=#{duration}\
    :size=#{video_description.width}x#{video_description.height}\
    :rate=#{video_description.framerate}\
    ,format=yuv420p\
    """

    {result, exit_status} =
      System.cmd(
        "ffmpeg",
        [
          # does not override the output file if it already exists
          "-y",
          # virtual input
          "-f",
          "lavfi",
          # video parameters
          "-i",
          video_description_str,
          # save as raw video
          "-f",
          "rawvideo",
          # output file name
          file_name
        ],
        stderr_to_stdout: true
      )

    if exit_status != 0 do
      raise inspect(result)
    end
  end

  @spec prepare_paths(binary(), binary(), binary()) :: {binary(), binary(), binary()}
  def prepare_paths(input_file_name, ref_file_name, tmp_dir) do
    in_path = "../fixtures/#{input_file_name}" |> Path.expand(__DIR__)
    ref_path = Path.join(tmp_dir, ref_file_name)
    out_path = Path.join(tmp_dir, "out-#{ref_file_name}")
    {in_path, out_path, ref_path}
  end

  @spec create_ffmpeg_reference(binary, binary, binary) :: nil | :ok
  def create_ffmpeg_reference(input_path, output_reference_path, filter_descr) do
    {result, exit_status} =
      System.cmd(
        "ffmpeg",
        [
          # overrides the output file without asking if it already exists
          "-y",
          # video input filename
          "-i",
          input_path,
          # description of the filter (transformation graph)
          "-vf",
          filter_descr,
          # video output filename
          output_reference_path
        ],
        stderr_to_stdout: true
      )

    if exit_status != 0 do
      raise inspect(result)
    end
  end

  @spec compare_contents(binary(), binary()) :: true
  def compare_contents(output_path, reference_path) do
    {:ok, reference_file} = File.read(reference_path)
    {:ok, output_file} = File.read(output_path)
    assert output_file == reference_file
  end
end
