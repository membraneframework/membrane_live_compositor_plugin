defmodule Membrane.VideoCompositor.Test.Utility do
  @moduledoc false
  import ExUnit.Assertions

  require Membrane.Logger

  @doc """
  Creates a video and prepares filenames for input, returns input, reference and output videos paths.
  """
  @spec prepare_testing_video(Membrane.RawVideo, integer(), binary()) ::
          {binary(), binary(), binary()}
  def prepare_testing_video(video_description, duration, extension) do
    res = video_description.height
    file_base = "#{duration}s_#{res}p.#{extension}"
    input_file_name = "input_#{file_base}"
    ref_file_name = "ref_#{file_base}"

    {input_file_name, out_file_name, ref_file_name} =
      prepare_paths(input_file_name, ref_file_name)

    generate_testing_video(input_file_name, video_description, duration)
    {input_file_name, out_file_name, ref_file_name}
  end

  @doc """
  Generate and save described video in the given filename.
  """
  @spec generate_testing_video(binary(), Membrane.RawVideo, integer()) :: nil | :ok
  def generate_testing_video(file_name, video_description, duration) do
    # ffmpeg -f lavfi -i testsrc=duration=4:size=1280x720:rate=30,format=yuv420p -f rawvideo test/fixtures/4s_30fps.raw
    {framerate, _} = video_description.framerate

    video_description_str = """
    testsrc=\
    duration=#{duration}\
    :size=#{video_description.width}x#{video_description.height}\
    :rate=#{framerate}\
    ,format=yuv420p\
    """

    input = [
      # does not override the output file if it already exists
      "-y",
      # virtual input
      "-f",
      "lavfi",
      # video parameters
      "-i",
      video_description_str
    ]

    # enforce raw video format, if needed
    raw_video =
      if(String.ends_with?(file_name, ".raw"),
        do: ["-f", " rawvideo"],
        else: []
      )

    output = [
      # output file name
      file_name
    ]

    File.mkdir_p!(Path.dirname(file_name))

    {result, exit_status} =
      System.cmd(
        "ffmpeg",
        input ++ raw_video ++ output,
        stderr_to_stdout: true
      )

    if exit_status != 0 do
      raise inspect(result)
    end

    :ok
  end

  @spec prepare_paths(binary(), binary(), binary()) :: {binary(), binary(), binary()}
  def prepare_paths(input_file_name, ref_file_name, sub_dir_name \\ "") do
    fixtures_dir =
      Path.join([
        File.cwd!(),
        "test",
        "fixtures",
        sub_dir_name
      ])

    tmp_dir = get_tmp_dir()

    in_path = Path.join(fixtures_dir, input_file_name)
    out_path = Path.join(tmp_dir, "out-#{ref_file_name}")
    ref_path = Path.join(tmp_dir, ref_file_name)
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

  @doc """
  Get tmp directory of the project.
  """
  @spec get_tmp_dir() :: binary()
  def get_tmp_dir() do
    Path.join(File.cwd!(), "tmp")
  end
end
