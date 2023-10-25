defmodule Membrane.VideoCompositor do
  @moduledoc """
  Membrane SDK for [VideoCompositor](https://github.com/membraneframework/video_compositor),
  used for dynamic, real-time video composition.

  This bin sends videos from input pads to VideoCompositor server via RTP and output composed videos received back.

  Inputs and outputs registration is automatic.
  On input and output registration `t:input_registered_message` and `t:output_registered_message` are send to parent.

  In any time user can send `t:vc_request\0` to bin
  to specify [scene](https://github.com/membraneframework/video_compositor/wiki/Main-concepts#scene),
  [register images](https://github.com/membraneframework/video_compositor/wiki/Api-%E2%80%90-renderers#image), 
  [shader](https://github.com/membraneframework/video_compositor/wiki/Api-%E2%80%90-renderers#shader) and
  any other request supported in VideoCompositor API.
  Bin sends request response as `t:vc_request_response` to parent.

  For more details, check out [VideoCompositor wiki](https://github.com/membraneframework/video_compositor/wiki/Main-concepts).
  """

  use Membrane.Bin

  require Membrane.Logger

  alias Membrane.{Pad, RTP, UDP}
  alias Membrane.VideoCompositor.{Context, InputState, OutputState, Resolution, State}
  alias Membrane.VideoCompositor.Request, as: VcReq

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
  Request that should be send to VideoCompositor. 
  Elixir types are mapped into JSON types:
  - map -> object
  - atom -> string
  """
  @type vc_request :: {:vc_request, body :: map()}

  @typedoc """
  VideoCompositor request response.
  """
  @type vc_request_response ::
          {:vc_request_response, request_body :: map(), Req.Response.t(), Context.t()}

  @typedoc """
  Message send to parent on input registration.
  """
  @type input_registered_message :: {:input_registered, Pad.ref(), input_id(), Context.t()}

  @typedoc """
  Message send to parent on output registration.
  """
  @type output_registered_message :: {:input_registered, Pad.ref(), output_id(), Context.t()}

  @local_host {127, 0, 0, 1}
  @udp_buffer_size 1024 * 1024

  def_options framerate: [
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
                default: Membrane.Time.seconds(10)
              ],
              start_composing_strategy: [
                spec: :on_init | :on_message,
                description:
                  "Specifies when VideoCompositor starts composing frames. In `:on_message` strategy, `:start_composing` message have to be send to start composing.",
                default: :on_init
              ],
              vc_server_port_number: [
                spec: non_neg_integer(),
                description:
                  "Port on which VC server should run. Port have to be unused. In case of running multiple VC elements, those values should be unique.",
                default: 8001
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
    vc_port = opt.vc_server_port_number
    :ok = start_vc_server(vc_port)

    :ok = VcReq.init(opt.framerate, opt.stream_fallback_timeout, opt.init_web_renderer?, vc_port)

    if opt.start_composing_strategy == :on_init do
      :ok = VcReq.start_composing(vc_port)
    end

    {[],
     %State{
       inputs: [],
       outputs: [],
       framerate: opt.framerate,
       vc_port: vc_port
     }}
  end

  @impl true
  def handle_pad_added(input_ref = Pad.ref(:input, pad_id), ctx, state = %State{inputs: inputs}) do
    input_id = ctx.options.input_id
    {:ok, input_port} = register_input_stream(input_id, state)

    state = %State{
      state
      | inputs: [
          %InputState{input_id: input_id, port_number: input_port, pad_ref: input_ref} | inputs
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

    {[notify_parent: {:input_registered, input_ref, input_id, State.ctx(state)}, spec: spec],
     state}
  end

  @impl true
  def handle_pad_added(
        output_ref = Pad.ref(:output, pad_id),
        ctx,
        state = %State{outputs: outputs}
      ) do
    {:ok, port} = register_output_stream(ctx.options, state)
    output_id = ctx.options.output_id

    state = %State{
      state
      | outputs: [
          %OutputState{
            output_id: output_id,
            pad_ref: output_ref,
            port_number: port,
            resolution: ctx.options.resolution
          }
          | outputs
        ]
    }

    spec =
      child({:upd_source, pad_id}, %UDP.Source{
        local_port_no: port,
        local_address: @local_host,
        recv_buffer_size: @udp_buffer_size
      })
      |> via_in(Pad.ref(:rtp_input, pad_id))
      |> child({:rtp_receiver, pad_id}, RTP.SessionBin)

    {[notify_parent: {:output_registered, output_ref, output_id, State.ctx(state)}, spec: spec],
     state}
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
    :ok = VcReq.start_composing(state.vc_port)
    {[], state}
  end

  @impl true
  def handle_parent_notification({:vc_request, request_body}, _ctx, state = %State{}) do
    case VcReq.send_custom_request(request_body, state.vc_port) do
      {:ok, response} ->
        if response.status != 200 do
          Membrane.Logger.error(
            "Request\n#{inspect(request_body)}\nfailed with error:\n#{inspect(response.body)}"
          )
        end

        {[notify_parent: {:vc_request_response, request_body, response, State.ctx(state)}], state}

      {:error, err} ->
        Membrane.Logger.error("Request: #{request_body} failed. Error: #{err}.")
        {[], state}
    end
  end

  @impl true
  def handle_parent_notification(_notification, _ctx, state = %State{}) do
    {[], state}
  end

  @impl true
  def handle_child_notification(
        {:new_rtp_stream, ssrc, _pt, _ext},
        {:rtp_receiver, pad_id},
        _ctx,
        state = %State{}
      ) do
    %OutputState{resolution: %Resolution{width: output_width, height: output_height}} =
      state.outputs
      |> Enum.find(fn %OutputState{pad_ref: Pad.ref(:output, id)} -> pad_id == id end)

    output_stream_format = %Membrane.H264{
      framerate: {state.framerate, 1},
      alignment: :nalu,
      stream_structure: :annexb,
      width: output_width,
      height: output_height
    }

    spec =
      get_child({:rtp_receiver, pad_id})
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: RTP.H264.Depayloader])
      |> child({:output_processor, pad_id}, %Membrane.VideoCompositor.OutputProcessor{
        output_stream_format: output_stream_format
      })
      |> bin_output(Pad.ref(:output, pad_id))

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(_msg, _child, _ctx, state) do
    {[], state}
  end

  @spec start_vc_server(:inet.port_number()) :: :ok
  defp start_vc_server(vc_port) do
    video_compositor_app_path = Mix.Tasks.DownloadCompositor.vc_app_path()

    unless File.exists?(video_compositor_app_path) do
      raise "Video Compositor binary is not available under search path: #{video_compositor_app_path}."
    end

    spawn(fn ->
      Mix.Tasks.DownloadCompositor.vc_app_path()
      |> Rambo.run([], env: %{"MEMBRANE_VIDEO_COMPOSITOR_API_PORT" => "#{vc_port}"})
    end)

    started? =
      0..30
      |> Enum.reduce_while(false, fn _i, _acc ->
        Process.sleep(100)

        case VcReq.send_custom_request(%{}, vc_port) do
          {:ok, _} ->
            {:halt, true}

          {:error, _reason} ->
            {:cont, false}
        end
      end)

    unless started? do
      raise "Failed to startup and connect to VideoCompositor server."
    end

    :ok
  end

  @spec register_input_stream(input_id(), State.t()) ::
          {:ok, :inet.port_number()} | :error
  defp register_input_stream(input_id, state) do
    try_register = fn input_port ->
      VcReq.register_input_stream(input_id, input_port, state.vc_port)
    end

    register_input_or_output(try_register, state)
  end

  @spec register_output_stream(map(), State.t()) ::
          {:ok, :inet.port_number()} | :error
  defp register_output_stream(pad_options, state) do
    try_register = fn output_port ->
      VcReq.register_output_stream(
        pad_options.output_id,
        output_port,
        pad_options.resolution,
        pad_options.encoder_preset,
        state.vc_port
      )
    end

    register_input_or_output(try_register, state)
  end

  @spec register_input_or_output((:inet.port_number() -> VcReq.req_result()), State.t()) ::
          {:ok, :inet.port_number()} | :error
  defp register_input_or_output(try_register, state) do
    6000..8000
    |> Enum.shuffle()
    |> Enum.reduce_while(:error, fn port, _acc -> try_port(try_register, port, state) end)
  end

  @spec try_port((:inet.port_number() -> VcReq.req_result()), :inet.port_number(), State.t()) ::
          {:halt, {:ok, :inet.port_number()}} | {:cont, :error}
  defp try_port(try_register, port, state) do
    if state |> State.used_ports() |> MapSet.member?(port) do
      {:cont, :error}
    else
      case try_register.(port) do
        :ok ->
          {:halt, {:ok, port}}

        {:error, %Req.Response{}} ->
          {:cont, :error}

        _other ->
          raise "Register input failed"
      end
    end
  end

  @spec remove_input(State.t(), Membrane.Pad.ref()) :: State.t()
  defp remove_input(state = %State{inputs: inputs}, input_ref) do
    input_id =
      inputs
      |> Enum.find(fn %InputState{pad_ref: ref} -> ref == input_ref end)
      |> then(fn %InputState{input_id: id} -> id end)

    :ok = VcReq.unregister_input_stream(input_id, state.vc_port)

    inputs = Enum.reject(inputs, fn %InputState{pad_ref: ref} -> ref == input_ref end)

    %State{state | inputs: inputs}
  end

  @spec remove_output(State.t(), Membrane.Pad.ref()) :: State.t()
  defp remove_output(state = %State{outputs: outputs}, output_ref) do
    output_id =
      outputs
      |> Enum.find(fn %OutputState{pad_ref: ref} -> ref == output_ref end)
      |> then(fn %OutputState{output_id: id} -> id end)

    outputs = Enum.reject(outputs, fn %OutputState{pad_ref: ref} -> ref == output_ref end)

    :ok = VcReq.unregister_output_stream(output_id, state.vc_port)

    %State{state | outputs: outputs}
  end
end
