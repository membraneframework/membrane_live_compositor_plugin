defmodule Membrane.VideoCompositor do
  @moduledoc false
  use Membrane.Bin

  require Membrane.Logger

  alias Req
  alias Membrane.{Pad, RTP, UDP}
  alias Membrane.VideoCompositor.{Handler, Resolution, State}
  alias Membrane.VideoCompositor.Request, as: VcReq

  @type encoder_preset ::
          :ultrafast
          | :superfast
          | :veryfast
          | :faster
          | :fast
          | :medium
          | :slow
          | :slower
          | :veryslow
          | :placebo

  @type ip :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type port_number :: non_neg_integer()
  @type input_id :: String.t()
  @type output_id :: String.t()

  @send_streams_ip_address {127, 0, 0, 1}
  @receive_streams_ip_address {127, 0, 0, 2}

  # TODO choose server ip
  def_options handler: [
                spec: Handler.t(),
                description:
                  "Module implementing `#{Membrane.VideoCompositor.Handler}` behaviour. 
                  Used for updating [Scene](https://github.com/membraneframework/video_compositor/wiki/Main-concepts#scene)."
              ],
              framerate: [
                spec: Membrane.H264.framerate(),
                description: "Stream format for the output video of the compositor"
              ],
              init_web_renderer?: [
                spec: boolean(),
                description:
                  "Enable web renderer support. If false, an attempt to register any transformation that is using a web renderer will fail.",
                default: true
              ],
              stream_fallback_timeout: [
                spec: Membrane.Time.t(),
                description:
                  "Timeout that defines when the compositor should switch to fallback on the input stream that stopped sending frames.",
                default: Membrane.Time.second()
              ],
              start_composing_strategy: [
                spec: :on_init | :on_message,
                description:
                  "Specifies when VideoCompositor starts composing frames.
                  In `:on_message` strategy, `:start_composing` message have to be send to start composing.",
                default: :on_init
              ]

  def_input_pad :input,
    accepted_format: %Membrane.H264{},
    availability: :on_request,
    options: [
      input_id: [
        spec: input_id(),
        description: "Input identifier."
      ]
    ]

  def_output_pad :output,
    accepted_format: %Membrane.H264{},
    availability: :on_request,
    options: [
      resolution: [
        spec: Resolution.t(),
        description: "Resolution of output stream."
      ],
      output_id: [
        spec: output_id(),
        description: "Output identifier."
      ],
      encoder_preset: [
        spec: encoder_preset(),
        description:
          "Preset for an encoder. See [FFmpeg docs](https://trac.ffmpeg.org/wiki/Encode/H.264#Preset) to learn more.",
        default: :medium
      ]
    ]

  @impl true
  def handle_init(_ctx, opt) do
    # :ok = start_video_compositor_server()

    :ok = VcReq.init(opt.framerate, opt.stream_fallback_timeout, opt.init_web_renderer?)

    if opt.start_composing_strategy == :on_init do
      :ok = VcReq.start_composing()
    end

    spec =
      child(:rtp_session_bin, %RTP.SessionBin{
        fmt_mapping: %{
          96 => {:H264, 90_000}
        }
      })

    {[spec: spec], %State{inputs: [], outputs: [], handler_state: %{}, handler: opt.handler}}
  end

  # TODO handle pad removed
  @impl true
  def handle_pad_added(pad_ref = Pad.ref(:input, pad_id), ctx, state = %State{inputs: inputs}) do
    state = add_input(state, pad_ref, ctx.options)

    spec =
      bin_input(pad_ref)
      |> via_in(pad_ref,
        options: [payloader: RTP.H264.Payloader]
      )
      |> get_child(:rtp_session_bin)
      |> via_out(Pad.ref(:rtp_output, pad_id), options: [encoding: :H264])
      |> child({:rtp_sender, pad_id}, %UDP.Sink{
        destination_port_no: get_port(length(inputs)),
        destination_address: @send_streams_ip_address
      })

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(
        output_ref = Pad.ref(:output, pad_id),
        ctx,
        state = %State{outputs: outputs}
      ) do
    state = add_output(state, output_ref, ctx.options)

    spec =
      child({:rtp_input_receiver, pad_id}, %UDP.Source{
        local_port_no: get_port(length(outputs)),
        local_address: @receive_streams_ip_address
      })
      |> via_in(:rtp_input)
      |> get_child(:rtp_session_bin)
      |> bin_output(Pad.ref(:output, pad_id))

    {[spec: spec], state}
  end

  @impl true
  def handle_parent_notification(:start_composing, _ctx, state = %State{}) do
    :ok = VcReq.start_composing()
    {[], state}
  end

  # TODO handle other parent notifications
  @impl true
  def handle_parent_notification(_notification, _ctx, state = %State{}) do
    {[], state}
  end

  @spec add_input(State.t(), Membrane.Pad.ref(), map()) :: State.t()
  defp add_input(state = %State{inputs: inputs}, input_ref, pad_options) do
    port_number = get_port(length(inputs))
    input_id = pad_options.input_id
    :ok = VcReq.register_input_stream(input_id, port_number)

    input_ctx = %{pad_ref: input_ref, input_id: input_id}
    state = %State{state | inputs: [input_ctx | inputs]}

    handle_pads_change(state)
  end

  @spec add_output(State.t(), Membrane.Pad.ref(), map()) :: State.t()
  defp add_output(state = %State{outputs: outputs}, output_ref, pad_options) do
    output_id = pad_options.output_id
    port_number = get_port(length(outputs))

    :ok =
      VcReq.register_output_stream(
        output_id,
        port_number,
        pad_options.resolution,
        pad_options.encoder_preset
      )

    output_ctx = %{pad_ref: output_ref, output_id: output_id}
    state = %State{state | outputs: [output_ctx | outputs]}

    handle_pads_change(state)
  end

  defp handle_pads_change(state) do
    case State.call_handle_pads_change(state) do
      {:update_scene, new_scene, state} ->
        :ok = VcReq.update_scene(new_scene)
        state

      state ->
        state
    end
  end

  @spec get_port(non_neg_integer()) :: port_number()
  defp get_port(used_stream) do
    8000 + used_stream * 2
  end
end
