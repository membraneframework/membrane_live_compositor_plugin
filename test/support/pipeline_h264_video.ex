defmodule Membrane.VideoCompositor.PipelineH264 do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_h264_video_path: String.t(),
        second_h264_video_path: String.t(),
        output_path: String.t()
      },
      caps: RawVideo,
      implementation: :ffmpeg | :opengl | :nx
  })
  """
  @impl true
  def handle_init(options) do
    children = %{
      file_src_1: %Membrane.File.Source{location: options.paths.first_h264_video_path},
      file_src_2: %Membrane.File.Source{location: options.paths.second_h264_video_path},
      parser_1: Membrane.H264.FFmpeg.Parser,
      parser_2: Membrane.H264.FFmpeg.Parser,
      decoder_1: Membrane.H264.FFmpeg.Decoder,
      decoder_2: Membrane.H264.FFmpeg.Decoder,
      compositor: %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      },
      encoder: Membrane.H264.FFmpeg.Encoder,
      file_sink: %Membrane.File.Sink{location: options.paths.output_path}
    }

    links = [
      link(:file_src_1)
      |> to(:parser_1)
      |> to(:decoder_1)
      |> via_in(:first_input)
      |> to(:compositor),
      link(:file_src_2)
      |> to(:parser_2)
      |> to(:decoder_2)
      |> via_in(:second_input)
      |> to(:compositor)
      |> to(:encoder)
      |> to(:file_sink)
    ]

    {{:ok, [spec: %ParentSpec{children: children, links: links}, playback: :playing]}, %{}}
  end

  @impl true
  def handle_element_end_of_stream({:file_sink, :input}, _context, state) do
    Membrane.Logger.bare_log(:info, "file_sink send EOS")
    {{:ok, [playback: :terminating]}, state}
  end

  @impl true
  def handle_element_end_of_stream({pad, _}, _context, state) do
    Membrane.Logger.bare_log(:info, "#{pad} send EOS")
    {:ok, state}
  end
end
