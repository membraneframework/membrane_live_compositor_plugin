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
      |> child(:video_parser, %H264.Parser{generate_best_effort_timestamps: %{framerate: {30, 1}}})
      |> via_in(Pad.ref(:input, 1), options: [input_id: "input_1"])
      |> child(:video_compositor, %Membrane.VideoCompositor{
        framerate: 30,
        handler: Membrane.VideoCompositor.SimpleHandler
      })
      |> via_out(Pad.ref(:output, 1),
        options: [resolution: %Resolution{width: 1280, height: 720}, output_id: "output_1"]
      )
      |> child(:sink, %Membrane.File.Sink{
        location: "output.h264"
      })

    {[spec: spec], %{}}
  end
end
