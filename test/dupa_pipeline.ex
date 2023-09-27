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

    spec = [
      child(:video_src, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child(:video_parser, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:realtimer, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 1), options: [payloader: RTP.H264.Payloader])
      |> child(:rtp_sender, RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, 1), options: [encoding: :H264])
      |> child(:udp_sink, %UDP.Sink{
        destination_port_no: 4000,
        destination_address: {127, 0, 0, 1}
      }),
      child(:upd_source, %UDP.Source{
        local_port_no: 5000,
        local_address: {127, 0, 0, 1}
      })
      |> via_in(Pad.ref(:rtp_input, 1))
      |> child(:rtp_receiver, RTP.SessionBin)
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, _pt, _ext}, :rtp_receiver, _ctx, state) do
    spec =
      get_child(:rtp_receiver)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: RTP.H264.Depayloader])
      |> child(:output_parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:decoder, H264.FFmpeg.Decoder)
      |> child(:player, Membrane.SDL.Player)

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(msg, child, _ctx, state) do
    IO.inspect({msg, child})
    {[], state}
  end
end
