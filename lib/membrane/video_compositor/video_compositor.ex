defmodule Membrane.LiveCompositor do
  @moduledoc """
  Membrane SDK for [LiveCompositor](https://github.com/membraneframework/video_compositor).

  ## Input streams
  Inputs are simply linked as Membrane Pads, no additional requests are required.
  Input registration happens automatically.
  After registering and linking an input stream the LiveCompositor will notify the parent with `t:input_registered_msg/0`.
  After receiving this message, input can be used in the scene defintion.

  ## Output streams
  Outputs have to be registered before linking.
  To register an output the parent sends `t:register_output_msg/0`.
  After registering output, the LiveCompositor will notify the parent with `t:output_registered_msg/0`.
  Scene for a specific output can only be defined after registration.
  Once LiveCompositor starts producing output stream, it will notify parent with `t:new_output_stream_msg/0`.
  Linking outputs is only available after receiving that message.

  ## Composition specification - `Scene`
  To specify what LiveCompositor should render parent should send `t:lc_request/0`.
  `Scene` is a top level specification of what LiveCompositor should render.

  As an example, if two inputs with IDs `"input_0"` and `"input_1"` and
  single output with ID `"output_0"` are registered, sending such `update_output`
  request would result in receiving inputs merged in layout on output:
  ```
  scene_update_request =  %{
    type: "update_output",
    output_id: "output_0"
    video: %{
      type: :tiles
      children: [
        { type: "input_stream", input_id: "input_0" },
        { type: "input_stream", input_id: "input_1" }
      ]
    }
  }

  {[notify_child: {:video_compositor, {:lc_request, scene_update_request}}]}
  ```
  LiveCompositor will notify parent with `t:lc_request_response/0`.

  You can use renderers/nodes to process input streams into outputs.
  LiveCompositor has builtin renders for most common use cases, but you can
  also register your own shaders, images and websites to tune LiveCompositor for
  specific business requirements.

  ## Pads unlinking
  Before unlinking pads make sure to remove them from the scene, otherwise VC will crash on pad unlinking.
  Inputs/outputs are unregistered automatically on pad unlinking.

  ## API reference
  You can find more detailed [API reference here](https://compositor.live/docs/api/routes).
  Only `update_output` and `register_renderer` request are available (`inputs`/`outputs` registration, `start` is done by SDK).

  ## General concepts
  General concepts of scene are explained [here](https://compositor.live/docs/concept/component).

  ## Examples
  Examples can be found in `examples` directory of Membrane LiveCompositor Plugin.
  `Scene` API usage examples can be found in the [LiveCompositor repo](https://github.com/membraneframework/video_compositor/tree/master/examples).
  """

  use Membrane.Bin

  require Membrane.Logger

  alias Membrane.{Opus, Pad, RemoteStream, RTP, TCP}

  alias Membrane.LiveCompositor.{
    Context,
    ServerRunner,
    State,
    StreamsHandler
  }

  alias Membrane.LiveCompositor.Request

  @typedoc """
  Preset of LiveCompositor video encoder.
  See [FFmpeg docs](https://trac.ffmpeg.org/wiki/Encode/H.264#Preset) to learn more.
  """
  @type video_encoder_preset ::
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
  Preset of LiveCompositor audio encoder.
  """
  @type audio_encoder_preset :: :quality | :voip | :lowest_latency

  @typedoc """
  Input stream id, used in scene after adding input stream.
  """
  @type input_id :: String.t()

  @typedoc """
  Output stream id, used in scene after adding output stream.
  """
  @type output_id :: String.t()

  @typedoc """
  Elixir translated body of LiveCompositor requests.

  This request body:
  ```
  %{
    type: "update_output",
    output_id: "output_0",
    video: %{
      type: :tiles
      children: [
        { type: "input_stream", input_id: "input_0" },
        { type: "input_stream", input_id: "input_1" }
      ]
    }
  }
  ```
  will translate into the following JSON:
  ```json
  {
    "type": "update_output",
    "output_id": "output",
    "video": {
      "type": "tiles",
      "children": [
        { "type": "input_stream", "input_id": "input_0" },
        { "type": "input_stream", "input_id": "input_1" }
      ]
    }
  }
  ```
  User of SDK should only send `update_output` or `register_renderer` requests.
  [API reference can be found here](https://compositor.live/docs/category/api-reference).
  """
  @type lc_request :: {:lc_request, map()}

  @typedoc """
  LiveCompositor request response.
  """
  @type lc_request_response ::
          {:lc_request_response, map(), Req.Response.t(), Context.t()}

  @typedoc """
  Notification sent to parent after LiveCompositor receives
  the first frame from the input stream (registered on input pad link).

  Input can be used in `scene` only after registration.
  """
  @type input_registered_msg :: {:input_registered, Pad.ref(), Context.t()}

  @typedoc """
  Notification sent to parent after LiveCompositor starts producing streams
  and in ready to link output pad.

  See "Output streams" section in doc for more information.
  """
  @type new_output_stream_msg :: {:new_output_stream, output_id(), Context.t()}

  @typedoc """
  Range of ports.
  """
  @type port_range :: {lower_bound :: :inet.port_number(), upper_bound :: :inet.port_number()}

  @typedoc """
  Supported output sample rates
  """
  @type output_sample_rate :: 8_000 | 12_000 | 16_000 | 24_000 | 48_000

  @local_host {127, 0, 0, 1}

  def_options framerate: [
                spec: Membrane.RawVideo.framerate_t(),
                description: "Framerate of LiveCompositor outputs."
              ],
              output_sample_rate: [
                spec: output_sample_rate(),
                default: 48_000,
                description: "Sample rate of audio on LiveCompositor outputs."
              ],
              api_port: [
                spec: :inet.port_number() | port_range(),
                description: """
                Port number or port range where API of a LiveCompositor will be hosted.
                """,
                default: 8081
              ],
              stream_fallback_timeout: [
                spec: Membrane.Time.t(),
                description: """
                Timeout that defines when the LiveCompositor should switch to fallback on the input stream that stopped sending frames.
                """,
                default: Membrane.Time.seconds(2)
              ],
              composing_strategy: [
                spec: :real_time_auto_init | :real_time | :ahead_of_time,
                description: """
                Specifies LiveCompositor mode for composing frames:
                - `:real_time` - Frames are produced in a rate dictaed by real time clock. Parrent
                process has to sent `:start_composing` message to start.
                - `:real_time_auto_init` - The same as `:real_time`, but pipeline starts
                automatically and sending `:start_composing` message is not necessary.
                - `:ahead_of_time` - Output streams will be produced faster than in the real time
                if inputs streams are ready. When using this option make sure to register output
                stream before starting, otherwise compositor will run in a busy loop processing
                data far into the future.
                """,
                default: :real_time_auto_init
              ],
              server_setup: [
                spec: :already_started | :start_locally | {:start_locally, path :: String.t()},
                description: """
                Defines how the LiveCompositor bin should start-up a LiveCompositor server.

                Available options:
                - :start_locally - LC server is automatically started.
                - :already_started - LiveCompositor bin assumes, that LC server is already started and is available on a specified port.
                When this option is selected, the `api_port` option need to specify an exact port number (not a range).
                """,
                default: :start_locally
              ],
              init_requests: [
                spec: list(any()),
                description: """
                Request that will send on startup to the LC server. It's main use case is to
                register renderers that will be needed in scene.
                """,
                default: []
              ]

  def_input_pad :video_input,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :on_request,
    options: [
      required: [
        spec: boolean(),
        default: false,
        description: """
        If stream is marked required the LiveCompositor will delay processing new frames until
        frames are available.
        In particular, if there is at least one required input stream and the encoder is not able
        to produce frames on time, the output stream will also be delayed. This delay will happen
        regardless of whether required input stream was on time or not.
        """
      ],
      offset: [
        spec: Membrane.Time.t() | nil,
        default: nil,
        description: """
        Optonal offset used for stream synchronization. This value represents how PTS values of the
        stream are shifted relative to the start request. If not defined streams are synchronized
        based on the delivery times of initial frames.
        """
      ],
      port: [
        spec: :inet.port_number() | port_range(),
        description: """
        Port number or port range.

        Internally LiveCompositor server communicates with this pipeline locally over RTP.
        This value defines which TCP ports will be used.
        """,
        default: {10_000, 60_000}
      ]
    ]

  def_input_pad :audio_input,
    accepted_format:
      any_of(
        %Opus{self_delimiting?: false},
        %RemoteStream{type: :packetized, content_format: Opus},
        %RemoteStream{type: :packetized, content_format: nil}
      ),
    availability: :on_request,
    options: [
      required: [
        spec: boolean(),
        default: false,
        description: """
        If stream is marked required the LiveCompositor will delay processing new frames until
        frames are available.
        In particular, if there is at least one required input stream and the encoder is not able
        to produce frames on time, the output stream will also be delayed. This delay will happen
        regardless of whether required input stream was on time or not.
        """
      ],
      offset: [
        spec: Membrane.Time.t() | nil,
        default: nil,
        description: """
        Optonal offset used for stream synchronization. This value represents how PTS values of the
        stream are shifted relative to the start request. If not defined streams are synchronized
        based on the delivery times of initial frames.
        """
      ],
      port: [
        spec: :inet.port_number() | port_range(),
        description: """
        Port number or port range.

        Internally LiveCompositor server communicates with this pipeline locally over RTP.
        This value defines which TCP ports will be used.
        """,
        default: {10_000, 60_000}
      ],
      channels: [
        spec: :stereo | :mono
      ]
    ]

  def_output_pad :video_output,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb},
    availability: :on_request,
    options: [
      port: [
        spec: :inet.port_number() | port_range(),
        description: """
        Port number or port range.

        Internally LiveCompositor server communicates with this pipeline locally over RTP.
        This value defines which TCP ports will be used.
        """,
        default: {10_000, 60_000}
      ],
      width: [
        spec: non_neg_integer()
      ],
      height: [
        spec: non_neg_integer()
      ],
      encoder_preset: [
        spec: video_encoder_preset(),
        default: :fast
      ],
      initial: [
        spec: any()
      ]
    ]

  def_output_pad :audio_output,
    accepted_format: %RemoteStream{type: :packetized, content_format: Opus},
    availability: :on_request,
    options: [
      port: [
        spec: :inet.port_number() | port_range(),
        description: """
        Port number or port range.

        Internally LiveCompositor server communicates with this pipeline locally over RTP.
        This value defines which TCP ports will be used.
        """,
        default: {10_000, 60_000}
      ],
      channels: [
        spec: :stereo | :mono
      ],
      encoder_preset: [
        spec: audio_encoder_preset(),
        default: :voip
      ],
      initial: [
        spec: any()
      ]
    ]

  @impl true
  def handle_init(_ctx, opt) do
    {[], opt}
  end

  @impl true
  def handle_setup(_ctx, opt) do
    {:ok, lc_port, server_pid} =
      ServerRunner.ensure_server_started(opt)

    if opt.composing_strategy == :real_time_auto_init do
      {:ok, _resp} = Request.start_composing(lc_port)
    end

    opt.init_requests |> Enum.each(fn request -> Request.send_request(request, lc_port) end)

    {[],
     %State{
       output_framerate: opt.framerate,
       output_sample_rate: opt.output_sample_rate,
       lc_port: lc_port,
       server_pid: server_pid,
       context: %Context{}
     }}
  end

  @impl true
  def handle_pad_added(input_ref = Pad.ref(:video_input, pad_id), ctx, state) do
    state = %State{state | context: Context.add_stream(input_ref, state.context)}

    {:ok, port} =
      StreamsHandler.register_video_input_stream(pad_id, ctx.pad_options, state)

    {state, ssrc} = State.next_ssrc(state)

    links =
      bin_input(input_ref)
      |> via_in(Pad.ref(:input, ssrc),
        options: [payloader: RTP.H264.Payloader]
      )
      |> child({:rtp_sender, pad_id}, RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, ssrc), options: [payload_type: 96])
      |> child({:tcp_encapsulator, pad_id}, RTP.TCP.Encapsulator)
      |> child({:tcp_sink, input_ref}, %TCP.Sink{
        connection_side: {:client, @local_host, port}
      })

    spec = {links, group: input_group_id(pad_id)}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(input_ref = Pad.ref(:audio_input, pad_id), ctx, state) do
    state = %State{state | context: Context.add_stream(input_ref, state.context)}

    {:ok, port} =
      StreamsHandler.register_audio_input_stream(pad_id, ctx.pad_options, state)

    {state, ssrc} = State.next_ssrc(state)

    links =
      bin_input(input_ref)
      |> via_in(Pad.ref(:input, ssrc),
        options: [payloader: RTP.Opus.Payloader]
      )
      |> child({:rtp_sender, pad_id}, RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, ssrc), options: [payload_type: 97, clock_rate: 48_000])
      |> child({:tcp_encapsulator, pad_id}, RTP.TCP.Encapsulator)
      |> child({:tcp_sink, input_ref}, %TCP.Sink{
        connection_side: {:client, @local_host, port}
      })

    spec = {links, group: input_group_id(pad_id)}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(output_ref = Pad.ref(:video_output, pad_id), ctx, state) do
    state = %State{state | context: Context.add_stream(output_ref, state.context)}
    {:ok, port} = StreamsHandler.register_video_output_stream(pad_id, ctx.pad_options, state)

    output_stream_format = %Membrane.H264{
      framerate: state.output_framerate,
      alignment: :nalu,
      stream_structure: :annexb,
      width: ctx.pad_options.width,
      height: ctx.pad_options.height
    }

    links =
      [
        child({:tcp_source, output_ref}, %TCP.Source{
          connection_side: {:client, @local_host, port}
        })
        |> child({:tcp_decapsulator, pad_id}, RTP.TCP.Decapsulator)
        |> via_in(Pad.ref(:rtp_input, pad_id))
        |> child({:rtp_receiver, output_ref}, RTP.SessionBin),
        child({:output_processor, pad_id}, %Membrane.LiveCompositor.VideoOutputProcessor{
          output_stream_format: output_stream_format
        })
        |> bin_output(Pad.ref(:video_output, pad_id))
      ]

    spec = {links, group: output_group_id(pad_id)}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(output_ref = Pad.ref(:audio_output, pad_id), ctx, state) do
    state = %State{state | context: Context.add_stream(output_ref, state.context)}
    {:ok, port} = StreamsHandler.register_audio_output_stream(pad_id, ctx.pad_options, state)

    links = [
      child({:tcp_source, output_ref}, %TCP.Source{
        connection_side: {:client, @local_host, port}
      })
      |> child({:tcp_decapsulator, pad_id}, RTP.TCP.Decapsulator)
      |> via_in(Pad.ref(:rtp_input, pad_id))
      |> child({:rtp_receiver, output_ref}, RTP.SessionBin),
      child({:output_processor, pad_id}, Membrane.LiveCompositor.AudioOutputProcessor)
      |> bin_output(Pad.ref(:audio_output, pad_id))
    ]

    spec = {links, group: output_group_id(pad_id)}

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(input_type, pad_id), _ctx, state)
      when input_type == :audio_input or
             input_type == :video_input do
    {:ok, _resp} = Request.unregister_input_stream(pad_id, state.lc_port)
    state = %State{state | context: Context.remove_input(pad_id, state.context)}
    {[remove_children: input_group_id(pad_id)], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(:video_output, pad_id), _ctx, state) do
    {:ok, _resp} = Request.unregister_output_stream(pad_id, state.lc_port)
    state = %State{state | context: Context.remove_output(pad_id, state.context)}
    {[remove_children: output_group_id(pad_id)], state}
  end

  @impl true
  def handle_pad_removed(Pad.ref(:audio_output, pad_id), _ctx, state) do
    {:ok, _resp} = Request.unregister_output_stream(pad_id, state.lc_port)
    state = %State{state | context: Context.remove_output(pad_id, state.context)}
    {[remove_children: output_group_id(pad_id)], state}
  end

  @impl true
  def handle_parent_notification(:start_composing, _ctx, state) do
    {:ok, _resp} = Request.start_composing(state.lc_port)
    {[], state}
  end

  @impl true
  def handle_parent_notification({:lc_request, request_body}, _ctx, state) do
    case Request.send_request(request_body, state.lc_port) do
      {res, response} when res == :ok or res == :error_response_code ->
        response_msg = {:lc_request_response, request_body, response, state.context}
        {[notify_parent: response_msg], state}

      {:error, exception} ->
        Membrane.Logger.error(
          "LiveCompositor failed to send a request: #{request_body}.\nException: #{exception}."
        )

        {[], state}
    end
  end

  @impl true
  def handle_parent_notification(notification, _ctx, state) do
    Membrane.Logger.warning(
      "LiveCompositor received unknown notification from the parent: #{inspect(notification)}!"
    )

    {[], state}
  end

  @impl true
  def handle_child_notification(
        {:new_rtp_stream, ssrc, _payload_type, _extensions},
        {:rtp_receiver, ref = Pad.ref(:video_output, pad_id)},
        _ctx,
        state = %State{}
      ) do
    links =
      get_child({:rtp_receiver, ref})
      |> via_out(Pad.ref(:output, ssrc),
        options: [depayloader: RTP.H264.Depayloader, clock_rate: 90_000]
      )
      |> get_child({:output_processor, pad_id})

    actions = [spec: {links, group: output_group_id(pad_id)}]

    {actions, state}
  end

  @impl true
  def handle_child_notification(
        {:new_rtp_stream, ssrc, _payload_type, _extensions},
        {:rtp_receiver, ref = Pad.ref(:audio_output, pad_id)},
        _ctx,
        state = %State{}
      ) do
    links =
      get_child({:rtp_receiver, ref})
      |> via_out(Pad.ref(:output, ssrc),
        options: [depayloader: RTP.Opus.Depayloader, clock_rate: 48_000]
      )
      |> get_child({:output_processor, pad_id})

    {[spec: {links, group: output_group_id(pad_id)}], state}
  end

  @impl true
  def handle_child_notification(
        {:connection_info, _ip, _port},
        {:tcp_sink, pad_ref},
        _ctx,
        state = %State{}
      ) do
    {[notify_parent: {:input_registered, pad_ref, state.context}], state}
  end

  @impl true
  def handle_child_notification(
        {:connection_info, _ip, _port},
        {:tcp_source, pad_ref},
        _ctx,
        state = %State{}
      ) do
    {[notify_parent: {:output_registered, pad_ref, state.context}], state}
  end

  @impl true
  def handle_child_notification(msg, child, _ctx, state) do
    Membrane.Logger.debug(
      "Unknown msg received from child: #{inspect(msg)}, child: #{inspect(child)}"
    )

    {[], state}
  end

  @impl true
  def handle_info(msg, _ctx, state) do
    Membrane.Logger.debug("Unknown msg received: #{inspect(msg)}")

    {[], state}
  end

  @impl true
  def handle_terminate_request(_ctx, state) do
    if state.server_pid do
      Process.exit(state.server_pid, :kill)
    end

    {[terminate: :normal], state}
  end

  @spec input_group_id(input_id()) :: String.t()
  defp input_group_id(input_id) do
    "input_group_#{input_id}"
  end

  @spec output_group_id(output_id()) :: String.t()
  defp output_group_id(output_id) do
    "output_group_#{output_id}"
  end
end
