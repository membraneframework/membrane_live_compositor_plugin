defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc false

  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opt) do
    spec =
      child(:video_src, %Membrane.File.Source{
        location: "samples/video.h264"
      })
      |> child(:video_parser, %Membrane.H264.FFmpeg.Parser{framerate: {30, 1}, alignment: :nal})
      |> child({:realtimer, 1}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 1))
      |> child(:video_compositor, %Membrane.VideoCompositor{framerate: {30, 1}})

    {[spec: spec], %{}}
  end
end
