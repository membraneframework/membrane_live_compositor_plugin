defmodule DupaPipeline do
  @moduledoc false

  use Membrane.Pipeline

  alias Membrane.VideoCompositor.Request, as: VcReq
  alias Membrane.VideoCompositor.{Scene, Resolution}
  alias Membrane.{H264, Pad, RTP, UDP}

  @impl true
  def handle_init(_ctx, _opt) do
    :ok = VcReq.init(30, Membrane.Time.second(), true)
    :ok = VcReq.start_composing()

    :ok = VcReq.register_input_stream("input", 4000)

    :ok =
      VcReq.register_output_stream("output", 5000, %Resolution{width: 1280, height: 720}, :medium)

    scene = %Scene{
      nodes: [
        %{
          node_id: "layout",
          type: "built-in",
          transformation: "tiled_layout",
          margin: 10,
          resolution: %{
            width: 1280,
            height: 720
          },
          input_pads: ["input"]
        }
      ],
      outputs: [%{output_id: "output", input_pad: "layout"}]
    }

    :ok = VcReq.update_scene(scene)

    spec =
      child(:video_src, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child(:video_parser, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:realtimer, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 1), options: [payloader: RTP.H264.Payloader])
      |> child(:rtp, RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, 1), options: [encoding: :H264])
      |> child(:udp_sink, %UDP.Sink{
        destination_port_no: 4000,
        destination_address: {127, 0, 0, 1}
      })

    {[spec: spec], %{}}
  end
end
