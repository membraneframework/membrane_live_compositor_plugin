defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc false

  use Membrane.Pipeline

  alias Membrane.VideoCompositor.Resolution
  alias Membrane.H264

  @impl true
  def handle_init(_ctx, _opt) do
    spec =
      child(:video_src, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child(:input_parser, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:realtimer, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 1), options: [input_id: "input_1"])
      |> child(:video_compositor, %Membrane.VideoCompositor{
        framerate: 30,
        handler: Membrane.VideoCompositor.SimpleHandler
      })
      |> via_out(Pad.ref(:output, 1),
        options: [resolution: %Resolution{width: 1280, height: 720}, output_id: "output_1"]
      )
      |> child(:output_parser, H264.Parser)
      |> child(:output_decoder, H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)

    {[spec: spec], %{}}
  end
end
