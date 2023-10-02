defmodule Membrane.VideoCompositor do
  @moduledoc false
  use Membrane.Bin

  require Membrane.Logger

  alias Req
  alias Membrane.{Pad, RTP, UDP}
  alias Membrane.VideoCompositor.{Handler, Resolution, Scene, State}
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

  @local_host {127, 0, 0, 1}

  def_options handler: [
                spec: Handler.t(),
                description:
                  "Module implementing `#{Membrane.VideoCompositor.Handler}` behaviour. 
                  Used for updating [Scene](https://github.com/membraneframework/video_compositor/wiki/Main-concepts#scene)."
              ],
              framerate: [
                spec: non_neg_integer(),
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
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :on_request,
    options: [
      input_id: [
        spec: input_id(),
        description: "Input identifier."
      ]
    ]

  def_output_pad :output,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
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

    {[],
     %State{
       inputs: [],
       outputs: [],
       handler_state: %{},
       handler: opt.handler,
       framerate: opt.framerate
     }}
  end

  @impl true
  def handle_pad_added(pad_ref = Pad.ref(:input, pad_id), ctx, state = %State{inputs: inputs}) do
    port = get_port(4000, length(inputs))
    state = add_input(state, pad_ref, ctx.options, port)

    spec =
      bin_input(Pad.ref(:input, pad_id))
      |> via_in(Pad.ref(:input, pad_id),
        options: [payloader: RTP.H264.Payloader]
      )
      |> child({:rtp_sender, pad_id}, RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, pad_id), options: [encoding: :H264])
      |> child({:upd_sink, pad_id}, %UDP.Sink{
        destination_port_no: port,
        destination_address: @local_host
      })

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(
        output_ref = Pad.ref(:output, pad_id),
        ctx,
        state = %State{outputs: outputs}
      ) do
    port = get_port(5000, length(outputs))
    state = add_output(state, output_ref, ctx.options, port)

    spec =
      child(Pad.ref(:upd_source, pad_id), %UDP.Source{
        local_port_no: port,
        local_address: @local_host
      })
      |> via_in(Pad.ref(:rtp_input, pad_id))
      |> child({:rtp_receiver, pad_id}, RTP.SessionBin)

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(input_ref = Pad.ref(:input, pad_id), _ctx, state = %State{}) do
    state = remove_input(state, input_ref)
    {[remove_child: [{:rtp_sender, pad_id}, {:upd_sink, pad_id}]], state}
  end

  @impl true
  def handle_pad_removed(output_ref = Pad.ref(:output, pad_id), _ctx, state = %State{}) do
    state = remove_output(state, output_ref)
    {[remove_child: [{:rtp_receiver, pad_id}, {:upd_source, pad_id}]], state}
  end

  @impl true
  def handle_parent_notification(:start_composing, _ctx, state = %State{}) do
    :ok = VcReq.start_composing()
    {[], state}
  end

  @impl true
  def handle_parent_notification(_notification, _ctx, state = %State{}) do
    {[], state}
  end

  @impl true
  def handle_parent_notification({:update_scene, scene = %Scene{}}, _ctx, state) do
    VcReq.update_scene(scene)
    {[], state}
  end

  @impl true
  def handle_parent_notification(msg, _ctx, state = %State{}) do
    state = handle_msg(msg, state)
    {[], state}
  end

  @impl true
  def handle_child_notification(
        {:new_rtp_stream, ssrc, _pt, _ext},
        {:rtp_receiver, pad_id},
        _ctx,
        state
      ) do
    spec =
      get_child({:rtp_receiver, pad_id})
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: RTP.H264.Depayloader])
      |> bin_output(Pad.ref(:output, pad_id))

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(_msg, _child, _ctx, state) do
    {[], state}
  end

  @spec add_input(State.t(), Membrane.Pad.ref(), map(), VideoCompositor.port()) :: State.t()
  defp add_input(state = %State{inputs: inputs}, input_ref, pad_options, port) do
    input_id = pad_options.input_id
    :ok = VcReq.register_input_stream(input_id, port)

    input_ctx = %{pad_ref: input_ref, input_id: input_id}
    state = %State{state | inputs: [input_ctx | inputs]}

    handle_pads_change(state)
  end

  @spec remove_input(State.t(), Membrane.Pad.ref()) :: State.t()
  defp remove_input(state = %State{inputs: inputs}, input_ref) do
    input_id =
      inputs
      |> Enum.find(fn input_ctx -> input_ctx.pad_ref == input_ref end)
      |> then(fn input_ctx -> input_ctx.input_id end)

    inputs = Enum.reject(inputs, fn input_ctx -> input_ctx.pad_ref == input_ref end)
    state = %State{state | inputs: inputs} |> handle_pads_change()

    :ok = VcReq.unregister_input_stream(input_id)
    state
  end

  @spec remove_output(State.t(), Membrane.Pad.ref()) :: State.t()
  defp remove_output(state = %State{outputs: outputs}, output_ref) do
    output_id =
      outputs
      |> Enum.find(fn output_ctx -> output_ctx.pad_ref == output_ref end)
      |> then(fn output_ctx -> output_ctx.output_id end)

    outputs = Enum.reject(outputs, fn output_ctx -> output_ctx.pad_ref == output_ref end)
    state = %State{state | outputs: outputs} |> handle_pads_change()

    :ok = VcReq.unregister_output_stream(output_id)
    state
  end

  @spec add_output(State.t(), Membrane.Pad.ref(), map(), VideoCompositor.port_number()) ::
          State.t()
  defp add_output(state = %State{outputs: outputs}, output_ref, pad_options, port) do
    output_id = pad_options.output_id

    :ok =
      VcReq.register_output_stream(
        output_id,
        port,
        pad_options.resolution,
        pad_options.encoder_preset
      )

    output_ctx = %{pad_ref: output_ref, output_id: output_id}
    state = %State{state | outputs: [output_ctx | outputs]}

    handle_pads_change(state)
  end

  @spec handle_pads_change(State.t()) :: State.t()
  defp handle_pads_change(state) do
    case State.call_handle_pads_change(state) do
      {:update_scene, new_scene, state} ->
        update_scene(new_scene)
        state

      state ->
        state
    end
  end

  @spec handle_msg(any(), State.t()) :: State.t()
  defp handle_msg(msg, state) do
    case State.call_handle_info(msg, state) do
      {:update_scene, new_scene, state} ->
        update_scene(new_scene)
        state

      state ->
        state
    end
  end

  @spec get_port(non_neg_integer(), non_neg_integer()) :: port_number()
  defp get_port(range_start, used_streams) do
    range_start + 2 * used_streams
  end

  @spec update_scene(Scene.t()) :: nil
  defp update_scene(new_scene) do
    :ok =
      case VcReq.update_scene(new_scene) do
        :ok ->
          :ok

        {:error, %Req.Response{body: body}} ->
          Membrane.Logger.info("Failed to update scene. Error: #{body}")
          :ok

        {:error, _else} ->
          :error
      end
  end
end
