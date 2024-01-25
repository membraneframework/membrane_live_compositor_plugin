defmodule Membrane.VideoCompositor do
  @moduledoc """
  Membrane SDK for [LiveCompositor](https://github.com/membraneframework/video_compositor).

  ## Input streams
  Inputs are simply linked as Membrane Pads, no additional requests are required.
  Input registration happens automatically.
  After registering and linking an input stream the VideoCompositor will notify the parent with `t:input_registered_msg/0`.
  After receiving this message, input can be used in the scene defintion.

  ## Output streams
  Outputs have to be registered before linking.
  To register an output the parent sends `t:register_output_msg/0`.
  After registering output, the VideoCompositor will notify the parent with `t:output_registered_msg/0`.
  Scene for a specific output can only be defined after registration.
  Once VideoCompositor starts producing output stream, it will notify parent with `t:new_output_stream_msg/0`.
  Linking outputs is only available after receiving that message.

  ## Composition specification - `Scene`
  To specify what VideoCompositor should render parent should send `t:vc_request/0`.
  `Scene` is a top level specification of what VideoCompositor should render.

  As an example, if two inputs with IDs `"input_0"` and `"input_1"` and
  single output with ID `"output"` are registered, sending such `update_scene`
  request would result in receiving inputs merged in layout on output:
  ```
  scene_update_request =  %{
    type: "update_scene",
    outputs: [
      %{
        output_id: "output"
        root: %{
          type: :tiles
          children: [
            { type: "input_stream", input_id: "input_0" },
            { type: "input_stream", input_id: "input_1" }
          ]
        }
      }
    ]
  }

  {[notify_child: {:video_compositor, {:vc_request, scene_update_request}}]}
  ```
  VideoCompositor will notify parent with `t:vc_request_response/0`.

  You can use renderers/nodes to process input streams into outputs.
  VideoCompositor has builtin renders for most common use cases, but you can
  also register your own shaders, images and websites to tune VideoCompositor for
  specific business requirements.

  ## Pads unlinking
  Before unlinking pads make sure to remove them from the scene, otherwise VC will crash on pad unlinking.
  Inputs/outputs are unregistered automatically on pad unlinking.

  ## API reference
  You can find more detailed [API reference here](https://compositor.live/docs/api/routes).
  Only `update_scene` and `register_renderer` request are available (`inputs`/`outputs` registration, `start` is done by SDK).

  ## General concepts
  General concepts of scene are explained [here](https://compositor.live/docs/concept/component).

  ## Examples
  Examples can be found in `examples` directory of Membrane VideoCompositor Plugin.
  `Scene` API usage examples can be found in the [LiveCompositor repo](https://github.com/membraneframework/video_compositor/tree/master/examples).
  """

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

  @typedoc """
  Elixir translated body of VideoCompositor requests.

  Elixir types are mapped into JSON types:
  - map -> object
  - atom -> string

  This request body:
  ```
  %{
    type: "update_scene",
    outputs: [
      %{
        output_id: "output"
        root: %{
          type: :tiles
          children: [
            { type: "input_stream", input_id: "input_0" },
            { type: "input_stream", input_id: "input_1" }
          ]
        }
      }
    ]
  }
  ```
  will translate into the following JSON:
  ```json
  {
    "type": "update_scene",
    "outputs": [
      {
        "output_id": "output",
        "root": {
          "type": "tiles",
          "children": [
            { "type": "input_stream", "input_id": "input_0" },
            { "type": "input_stream", "input_id": "input_1" }
          ]
        }
      }
    ]
  }
  ```
  """
  @type request_body :: map()

  @typedoc """
  Request send to VideoCompositor.

  User of SDK should only send `update_scene` or `register_renderer` requests.
  [API reference can be found here](https://github.com/membraneframework/video_compositor/wiki/API-%E2%80%90-general#update-scene).
  """
  @type vc_request :: {:vc_request, request_body()}

  @typedoc """
  VideoCompositor request response.
  """
  @type vc_request_response ::
          {:vc_request_response, request_body(), Req.Response.t(), Context.t()}

  @typedoc """
  Notification sent to parent after VideoCompositor receives
  the first frame from the input stream (registered on input pad link).

  Input can be used in `scene` only after registration.
  """
  @type input_registered_msg :: {:input_registered, input_id(), Context.t()}

  @typedoc """
  Notification sent to VideoCompositor to register output stream.

  See "Output streams" section in the documentation for more information.
  """
  @type register_output_msg :: {:register_output, OutputOptions.t()}

  @typedoc """
  Notification sent to parent after output registration.

  Output can be used in `scene` only after registration.
  """
  @type output_registered_msg :: {:output_registered, output_id(), Context.t()}

  @typedoc """
  Notification sent to parent after VideoCompositor starts producing streams
  and in ready to link output pad.

  See "Output streams" section in doc for more information.
  """
  @type new_output_stream_msg :: {:new_output_stream, output_id(), Context.t()}

  @typedoc """
  Range in which VideoCompositor search available ports.

  This range should be at least a few times wider then expected sum
  of inputs and outputs.
  """
  @type port_range :: {lower_bound :: :inet.port_number(), upper_bound :: :inet.port_number()}

  @local_host {127, 0, 0, 1}
  @input_received_msg :input_stream_received

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
                default: Membrane.Time.seconds(2)
              ],
              start_composing_strategy: [
                spec: :on_init | :on_message,
                description: """
                Specifies when VideoCompositor starts composing frames.
                In `:on_message` strategy, `:start_composing` message has to be sent to start composing.
                """,
                default: :on_init
              ],
              vc_server_config: [
                spec:
                  :start_on_random_port
                  | {:start_on_port, :inet.port_number()}
                  | {:already_started, :inet.port_number()},
                description: """
                Defines how the VideoCompositor bin should start-up a LiveCompositor server.

                There are three available options:
                - :start_on_random_port - LC server is automatically started on port randomly chosen
                from port_range.
                - :start_on_port - LC server is automatically started on specified port.
                - :already_started - VideoCompositor bin assumes, that LC server is already started, initialized and should be
                available at specified port. Useful for sharing LC server between multiple pipelines or running custom version
                of LC server.
                """,
                default: :start_on_random_port
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
    env = %{
      LIVE_COMPOSITOR_WEB_RENDERER_ENABLE: to_string(opt.init_web_renderer?),
      LIVE_COMPOSITOR_OUTPUT_FRAMERATE: to_string(opt.framerate),
      LIVE_COMPOSITOR_STREAM_FALLBACK_TIMEOUT_MS:
        to_string(Membrane.Time.as_milliseconds(opt.stream_fallback_timeout, :round))
    }

    {:ok, vc_port} =
      case opt.vc_server_config do
        :start_on_random_port ->
          {port_lower_bound, port_upper_bound} = opt.port_range

          {:ok, vc_port} =
            port_lower_bound..port_upper_bound
            |> Enum.shuffle()
            |> Enum.reduce_while(
              {:error, "Failed to start a LiveCompositor server on any of the ports."},
              fn port, err -> try_starting_on_port(port, err, env) end
            )

          {:ok, vc_port}

        {:start_on_port, vc_port} ->
          :ok = ServerRunner.start_vc_server(vc_port, env)
          {:ok, vc_port}

        {:already_started, vc_port} ->
          {:ok, vc_port}
      end

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
    input_id = ctx.pad_options.input_id
    {:ok, input_port} = StreamsHandler.register_input_stream(input_id, state)

    # Don't optimize this with [%State.Input{...} | inputs]
    # Adding this at the beginning is O(1) instead of O(N),
    # but this way this list is always ordered by insert order.
    # Since this list should be small, preserving order with O(N) is better
    # (order is preserved in returned VC context, state is more consistent etc.)
    state = %State{
      state
      | inputs: inputs ++ [%State.Input{id: input_id, port: input_port, pad_ref: input_ref}]
    }

    links =
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

    spec = {links, group: input_group_id(input_id)}

    vc_pid = self()

    spawn(fn ->
      {:ok, _response} = Request.wait_for_frame_on_input(input_id, state.vc_port)
      send(vc_pid, {:input_stream_received, input_id})
    end)

    {[spec: spec], state}
  end

  @impl true
  def handle_pad_added(
        output_ref = Pad.ref(:output, _pad_id),
        ctx,
        state = %State{outputs: outputs}
      ) do
    %State.Output{ssrc: ssrc, id: output_id, width: width, height: height} =
      outputs |> Enum.find(fn %State.Output{id: id} -> id == ctx.pad_options.output_id end)

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

    links =
      get_child({:rtp_receiver, output_id})
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: RTP.H264.Depayloader])
      |> child({:output_processor, output_id}, %Membrane.VideoCompositor.OutputProcessor{
        output_stream_format: output_stream_format
      })
      |> bin_output(output_ref)

    spec = {links, group: output_group_id(output_id)}

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
  def handle_pad_removed(input_ref = Pad.ref(:input, _pad_id), _ctx, state = %State{}) do
    %State.Input{id: input_id} =
      state.inputs |> Enum.find(fn %State.Input{pad_ref: ref} -> ref == input_ref end)

    {:ok, _resp} = Request.unregister_input_stream(input_id, state.vc_port)

    inputs = state.inputs |> Enum.reject(fn %State.Input{pad_ref: ref} -> ref == input_ref end)

    {[remove_children: input_group_id(input_id)], %State{state | inputs: inputs}}
  end

  @impl true
  def handle_pad_removed(output_ref = Pad.ref(:output, _pad_id), _ctx, state = %State{}) do
    %State.Output{id: output_id} =
      state.outputs
      |> Enum.find(fn %State.Output{pad_ref: ref} -> ref == output_ref end)

    {:ok, _resp} = Request.unregister_output_stream(output_id, state.vc_port)

    outputs =
      state.outputs |> Enum.reject(fn %State.Output{pad_ref: ref} -> ref == output_ref end)

    {[remove_children: output_group_id(output_id)], %State{state | outputs: outputs}}
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

    links =
      child({:udp_source, id}, %UDP.Source{
        local_port_no: port,
        local_address: @local_host
      })
      |> via_in(Pad.ref(:rtp_input, id))
      |> child({:rtp_receiver, id}, RTP.SessionBin)

    spec = {links, group: output_group_id(id)}

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
        Membrane.Logger.error(
          "VideoCompositor failed to send a request: #{request_body}.\nException: #{exception}."
        )

        {[], state}
    end
  end

  @impl true
  def handle_parent_notification(notification, _ctx, state = %State{}) do
    Membrane.Logger.warning(
      "VideoCompositor received unknown notification from the parent: #{inspect(notification)}!"
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
    Membrane.Logger.debug(
      "Unknown msg received from child: #{inspect(msg)}, child: #{inspect(child)}"
    )

    {[], state}
  end

  @impl true
  def handle_info({@input_received_msg, input_id}, _ctx, state) do
    {[notify_parent: {:input_registered, input_id, Context.new(state)}], state}
  end

  @impl true
  def handle_info(msg, _ctx, state) do
    Membrane.Logger.debug("Unknown msg received: #{inspect(msg)}")

    {[], state}
  end

  @spec try_starting_on_port(:inet.port_number(), String.t(), map()) ::
          {:halt, {:ok, :inet.port_number()}} | {:cont, err :: String.t()}
  defp try_starting_on_port(port, err, env) do
    Membrane.Logger.debug("Trying to launch LiveCompositor on port: #{port}")

    case ServerRunner.start_vc_server(port, env) do
      :ok -> {:halt, {:ok, port}}
      :error -> {:cont, err}
    end
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
