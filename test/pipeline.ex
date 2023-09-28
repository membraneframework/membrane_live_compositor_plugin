defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc false

  use Membrane.Pipeline

  alias Membrane.H264
  alias Membrane.VideoCompositor.Resolution

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

    # output have to be added after init of VideoCompositor
    spec_2 =
      get_child(:video_compositor)
      |> via_out(:output,
        options: [resolution: %Resolution{width: 1280, height: 720}, output_id: "output_1"]
      )
      |> child(:output_decoder, H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)

    {[spec: spec, spec: spec_2], %{}}
  end

  @impl true
  def handle_child_notification(_msg, _child, _ctx, state) do
    {[], state}
  end
end
