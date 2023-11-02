defmodule Membrane.VideoCompositor do
  @moduledoc false

  use Membrane.Bin

  require Membrane.Logger

  alias Membrane.{Pad, RTP, UDP}

  alias Membrane.VideoCompositor.{
    Context,
    OutputOptions,
    ServerRunner,
    State,
    StreamsHandler
  }

  alias Membrane.VideoCompositor.Request

  @typedoc """
  Preset of VideoCompositor output video encoder.
  See [FFmpeg docs](https://trac.ffmpeg.org/wiki/Encode/H.264#Preset) to learn more.
  """
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

  @typedoc """
  Input stream id, used in scene after adding input stream.
  """
  @type input_id :: String.t()

  @typedoc """
  Output stream id, used in scene after adding output stream.
  """
  @type output_id :: String.t()

  @type request_body :: map()

  @typedoc """
  Request that should be send to VideoCompositor.
  Elixir types are mapped into JSON types:
  - map -> object
  - atom -> string
  """
  @type vc_request :: {:vc_request, request_body()}

  @typedoc """
  VideoCompositor request response.
  """
  @type vc_request_response ::
          {:vc_request_response, request_body(), Req.Response.t(), Context.t()}

  @typedoc """
  Message send to parent after input registration.
  """
  @type input_registered_msg :: {:input_registered, input_id(), Context.t()}

  @type register_output_stream_msg :: {:register_output, OutputOptions.t()}

  @type output_registered_msg :: {:output_registered, output_id(), Context.t()}

  @type new_output_stream_msg :: {:new_output_stream, output_id(), Context.t()}

  @type port_range :: {lower_bound :: :inet.port_number(), upper_bound :: :inet.port_number()}

  @local_host {127, 0, 0, 1}
  @udp_buffer_size 1024 * 1024

  def_options framerate: [
                spec: Membrane.RawVideo.framerate_t(),
                description: "Framerate of VideoCompositor outputs."
              ],
              port_range: [
                spec: port_range(),
                description: """
                Port range in which input and output streams would try to be registered.
                If all ports in range will be used, VideoCompositor will crash on input/output registration.
                """,
                default: {6000, 10_000}
              ],
              init_web_renderer?: [
                spec: boolean(),
                description: """
                Enables web rendering for VideoCompositor.
                If set to false, attempts to register and use web renderers will fail.
                """,
                default: true
              ],
              stream_fallback_timeout: [
                spec: Membrane.Time.t(),
                description: """
                Timeout that defines when the VideoCompositor should switch to fallback on the input stream that stopped sending frames.
                """,
                default: Membrane.Time.seconds(10)
              ],
              start_composing_strategy: [
                spec: :on_init | :on_message,
                description: """
                Specifies when VideoCompositor starts composing frames.
                In `:on_message` strategy, `:start_composing` message have to be send to start composing.
                """,
                default: :on_init
              ],
              vc_server_port_number: [
                spec: :inet.port_number() | :choose_at_random,
                description: """
                Port on which VC server should run.
                The port has to be unused. In case of running multiple VC elements, those values should be unique.
                """,
                default: :choose_at_random
              ]

  def_input_pad :input,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :on_request,
    options: [
      input_id: [
        spec: input_id()
      ]
    ]

  def_output_pad :output,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :on_request,
    options: [
      output_id: [
        spec: output_id()
      ]
    ]

  @impl true
  def handle_init(_ctx, opt) do
    {[], opt}
  end

  @impl true
  def handle_setup(_ctx, opt) do
    vc_port =
      case opt.vc_server_port_number do
        :choose_at_random ->
          {port_lower_bound, port_upper_bound} = opt.port_range

          [port] =
            port_lower_bound..port_upper_bound
            |> Enum.take_random(1)

          port

        port when is_integer(port) ->
          port
      end

    :ok = ServerRunner.start_vc_server(vc_port)

    {:ok, _resp} =
      Request.init(
        opt.framerate,
        opt.stream_fallback_timeout,
        opt.init_web_renderer?,
        vc_port
      )

    if opt.start_composing_strategy == :on_init do
      {:ok, _resp} = Request.start_composing(vc_port)
    end

    {[],
     %State{
       framerate: opt.framerate,
       vc_port: vc_port,
       port_range: opt.port_range
     }}
  end

  @impl true
  def handle_pad_added(input_ref = Pad.ref(:input, pad_id), ctx, state = %State{inputs: inputs}) do
    input_id = ctx.options.input_id
    {:ok, input_port} = StreamsHandler.register_input_stream(input_id, state)

    state = %State{
      state
      | inputs: [
          %State.Input{id: input_id, port: input_port, pad_ref: input_ref} | inputs
        ]
    }

    spec =
      bin_input(input_ref)
      |> via_in(input_ref,
        options: [payloader: RTP.H264.Payloader]
      )
      |> child({:rtp_sender, pad_id}, RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, pad_id), options: [encoding: :H264])
      |> child({:upd_sink, pad_id}, %UDP.Sink{
        destination_port_no: input_port,
        destination_address: @local_host
      })

    {[notify_parent: {:input_registered, input_id, Context.new(state)}, spec: spec], state}
  end

  @impl true
  def handle_pad_added(
        output_ref = Pad.ref(:output, _pad_id),
        ctx,
        state = %State{outputs: outputs}
      ) do
    %State.Output{ssrc: ssrc, id: output_id, width: width, height: height} =
      outputs |> Enum.find(fn %State.Output{id: id} -> id == ctx.options.output_id end)

    if ssrc == :stream_not_received do
      raise """
      Attempt to link output pad: #{inspect(output_ref)} to VideoCompositor, that hasn't been properly registered.
      Linking outputs is only allowed after registering them with `register_output` message.
      Send `register_output` message first and wait for receiving `output_registered` message.
      See VideoCompositor docs to learn more: https://hexdocs.pm/membrane_video_compositor_plugin/Membrane.VideoCompositor.html
      """
    end

    output_stream_format = %Membrane.H264{
      framerate: {state.framerate, 1},
      alignment: :nalu,
      stream_structure: :annexb,
      width: width,
      height: height
    }

    spec =
      get_child({:rtp_receiver, output_id})
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: RTP.H264.Depayloader])
      |> child({:output_processor, output_id}, %Membrane.VideoCompositor.OutputProcessor{
        output_stream_format: output_stream_format
      })
      |> bin_output(output_ref)

    update_output_state = fn output_state = %State.Output{id: id} ->
      if id == output_id do
        %State.Output{
          output_state
          | pad_ref: output_ref
        }
      else
        output_state
      end
    end

    outputs = state.outputs |> Enum.map(fn output_state -> update_output_state.(output_state) end)

    state = %State{
      state
      | outputs: outputs
    }

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(input_ref = Pad.ref(:input, pad_id), _ctx, state = %State{}) do
    {:ok, _resp} =
      state.inputs
      |> Enum.find(fn %State.Input{pad_ref: ref} -> ref == input_ref end)
      |> then(fn %State.Input{id: id} -> Request.unregister_input_stream(id, state.vc_port) end)

    inputs = state.inputs |> Enum.reject(fn %State.Input{pad_ref: ref} -> ref == input_ref end)

    {[remove_child: [{:rtp_sender, pad_id}, {:upd_sink, pad_id}]], %State{state | inputs: inputs}}
  end

  @impl true
  def handle_pad_removed(output_ref = Pad.ref(:output, _pad_id), _ctx, state = %State{}) do
    output_id =
      state.outputs
      |> Enum.find(fn %State.Output{pad_ref: ref} -> ref == output_ref end)
      |> then(fn %State.Output{id: id} -> id end)

    outputs =
      state.outputs |> Enum.reject(fn %State.Output{pad_ref: ref} -> ref == output_ref end)

    {:ok, _resp} = Request.unregister_output_stream(output_id, state.vc_port)

    output_children = [
      {:rtp_receiver, output_id},
      {:upd_source, output_id},
      {:rtp_receiver, output_id},
      {:output_processor, output_id}
    ]

    {[remove_child: output_children], %State{state | outputs: outputs}}
  end

  @impl true
  def handle_parent_notification(:start_composing, _ctx, state = %State{}) do
    {:ok, _resp} = Request.start_composing(state.vc_port)
    {[], state}
  end

  @impl true
  def handle_parent_notification(
        {:register_output, output_opt = %OutputOptions{id: id, width: width, height: height}},
        _ctx,
        state = %State{outputs: outputs}
      ) do
    {:ok, port} = StreamsHandler.register_output_stream(output_opt, state)

    output_state = %State.Output{
      id: id,
      width: width,
      height: height,
      port: port
    }

    state = %State{
      state
      | outputs: [output_state | outputs]
    }

    spec =
      child({:upd_source, id}, %UDP.Source{
        local_port_no: port,
        local_address: @local_host,
        recv_buffer_size: @udp_buffer_size
      })
      |> via_in(Pad.ref(:rtp_input, id))
      |> child({:rtp_receiver, id}, RTP.SessionBin)

    output_registered_msg = {:output_registered, output_opt.id, Context.new(state)}

    {[spec: spec, notify_parent: output_registered_msg], state}
  end

  @impl true
  def handle_parent_notification({:vc_request, request_body}, _ctx, state = %State{}) do
    case Request.send_request(request_body, state.vc_port) do
      {res, response} when res == :ok or res == :error_response_code ->
        response_msg = {:vc_request_response, request_body, response, Context.new(state)}
        {[notify_parent: response_msg], state}

      {:error, exception} ->
        Membrane.Logger.error("""
        VideoCompositor failed to send request: #{request_body}.\nException: #{exception}.
        """)

        {[], state}
    end
  end

  @impl true
  def handle_parent_notification(notification, _ctx, state = %State{}) do
    Membrane.Logger.warning(
      "VideoCompositor received unknown notification from parent: #{inspect(notification)}!"
    )

    {[], state}
  end

  @impl true
  def handle_child_notification(
        {:new_rtp_stream, ssrc, _payload_type, _extensions},
        {:rtp_receiver, output_id},
        _ctx,
        state = %State{}
      ) do
    update_output_state = fn output_state = %State.Output{id: id} ->
      if id == output_id do
        %State.Output{
          output_state
          | ssrc: ssrc
        }
      else
        output_state
      end
    end

    state =
      state.outputs
      |> Enum.map(fn output_state -> update_output_state.(output_state) end)
      |> then(fn outputs -> %State{state | outputs: outputs} end)

    {[notify_parent: {:new_output_stream, output_id, Context.new(state)}], state}
  end

  @impl true
  def handle_child_notification(msg, child, _ctx, state) do
    Membrane.Logger.info(
      "Unknown msg received from child: #{inspect(msg)}, child: #{inspect(child)}"
    )

    {[], state}
  end
end
