defmodule Membrane.VideoCompositor do
  @moduledoc false
  use Membrane.Bin

  require Membrane.Logger

  alias Membrane.{Pad, RTP, UDP}
  alias Membrane.VideoCompositor.{InputState, OutputState, Resolution, State}
  alias Membrane.VideoCompositor.Request, as: VcReq
  alias Rambo
  alias Req

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
    :ok = start_vc_server()

    :ok = VcReq.init(opt.framerate, opt.stream_fallback_timeout, opt.init_web_renderer?)

    if opt.start_composing_strategy == :on_init do
      :ok = VcReq.start_composing()
    end

    {[],
     %State{
       inputs: [],
       outputs: [],
       framerate: opt.framerate
     }}
  end

  @impl true
  def handle_pad_added(input_ref = Pad.ref(:input, pad_id), ctx, state = %State{inputs: inputs}) do
    port = get_port(4000, length(inputs))
    input_id = ctx.options.input_id
    state = add_input(state, input_ref, input_id, port)

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

    {[notify_parent: {:input_registered, input_ref, input_id, State.ctx(state)}, spec: spec],
     state}
  end

  @impl true
  def handle_pad_added(
        output_ref = Pad.ref(:output, pad_id),
        ctx,
        state = %State{outputs: outputs}
      ) do
    port = get_port(5000, length(outputs))
    state = add_output(state, output_ref, ctx.options, port)
    output_id = ctx.options.output_id

    spec =
      child(Pad.ref(:upd_source, pad_id), %UDP.Source{
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
    :ok = VcReq.start_composing()
    {[], state}
  end

  @impl true
  def handle_parent_notification({:vc_request, request_body}, _ctx, state = %State{}) do
    case VcReq.send_custom_request(request_body) do
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

  @spec start_vc_server() :: :ok
  defp start_vc_server() do
    architecture = system_architecture() |> Atom.to_string()

    vc_app_path =
      File.cwd!()
      |> Path.join("video_compositor_app/#{architecture}/video_compositor/video_compositor")

    spawn(fn -> Rambo.run(vc_app_path) end)

    :timer.sleep(1000)
    :ok
  end

  @spec system_architecture() :: :darwin_aarch64 | :darwin_x86_64 | :linux_x86_64
  defp system_architecture() do
    case :os.type() do
      {:unix, :darwin} ->
        system_architecture = :erlang.system_info(:system_architecture) |> to_string()

        cond do
          Regex.match?(~r/aarch64/, system_architecture) ->
            :darwin_aarch64

          Regex.match?(~r/x86_64/, system_architecture) ->
            :darwin_x86_64

          true ->
            raise "Unsupported system architecture: #{system_architecture}"
        end

      {:unix, :linux} ->
        :linux_x86_64

      os_type ->
        raise "Unsupported os type: #{os_type}"
    end
  end

  @spec add_input(State.t(), Membrane.Pad.ref(), input_id(), port_number()) :: State.t()
  defp add_input(state = %State{inputs: inputs}, input_ref, input_id, port) do
    :ok = VcReq.register_input_stream(input_id, port)

    %State{state | inputs: [%InputState{input_id: input_id, pad_ref: input_ref} | inputs]}
  end

  @spec remove_input(State.t(), Membrane.Pad.ref()) :: State.t()
  defp remove_input(state = %State{inputs: inputs}, input_ref) do
    input_id =
      inputs
      |> Enum.find(fn %InputState{pad_ref: ref} -> ref == input_ref end)
      |> then(fn %InputState{input_id: id} -> id end)

    :ok = VcReq.unregister_input_stream(input_id)

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

    :ok = VcReq.unregister_output_stream(output_id)

    %State{state | outputs: outputs}
  end

  @spec add_output(State.t(), Membrane.Pad.ref(), map(), port_number()) ::
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

    %State{state | outputs: [output_ctx | outputs]}
  end

  @spec get_port(non_neg_integer(), non_neg_integer()) :: port_number()
  defp get_port(range_start, used_streams) do
    range_start + 2 * used_streams
  end
end
