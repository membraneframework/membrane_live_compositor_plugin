defmodule Membrane.VideoCompositor do
  @moduledoc false
  use Membrane.Bin

  require Membrane.Logger

  alias Req
  alias Membrane.{Pad, RTP, UDP}
  alias Membrane.VideoCompositor.{Resolution, State}
  alias Membrane.VideoCompositor.Request, as: VcReq

  @typedoc """
  Preset for an encoder. See [FFmpeg docs](https://trac.ffmpeg.org/wiki/Encode/H.264#Preset) to learn more.
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

  @type ip :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type port :: non_neg_integer()
  @type input_id :: String.t()
  @type output_id :: String.t()

  # TODO choose server ip
  def_options handler: [
                spec: Membrane.VideoCompositor.Handler.t(),
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
      ]
    ]

  @impl true
  def handle_init(_ctx, opt) do
    :ok = start_video_compositor_server()

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

    {[spec: spec], %State{input_count: 0}}
  end

  @send_streams_ip_address {127, 0, 0, 1}
  @receive_streams_ip_address {127, 0, 0, 2}

  @impl true
  def handle_pad_added(Pad.ref(:input, pad_id), _ctx, state = %State{input_count: input_count}) do
    port_number = input_port(input_count)

    case VcReq.register_input_stream(pad_id, port_number) do
      :ok ->
        spec =
          bin_input(Pad.ref(:input, pad_id))
          |> via_in(Pad.ref(:input, pad_id),
            options: [payloader: RTP.H264.Payloader]
          )
          |> get_child(:rtp_session_bin)
          |> via_out(Pad.ref(:rtp_output, pad_id), options: [encoding: :H264])
          |> child({:rtp_sender, pad_id}, %UDP.Sink{
            destination_port_no: port_number,
            destination_address: @send_streams_ip_address
          })

        {[spec: spec], %State{state | input_count: input_count + 1}}

      {:error, reason} ->
        Membrane.Logger.error("Failed to register input stream. Reason: #{reason}")
        {[], state}
    end
  end

  @impl true
  def handle_pad_added(Pad.ref(:output, pad_id), _ctx, state = %State{output_count: output_count}) do
    port_number = output_port(output_count)

    case VcReq.register_output_stream(pad_id, port_number, %Resolution{width: 1920, height: 1080}) do
      :ok ->
        spec =
          child({:rtp_input_receiver, pad_id}, %UDP.Source{
            local_port_no: output_port(output_count),
            local_address: @receive_streams_ip_address
          })
          |> via_in(:rtp_input)
          |> get_child(:rtp_session_bin)
          |> bin_output(Pad.ref(:output, pad_id))

        {[spec: spec], %State{state | output_count: output_count + 1}}

      {:error, reason} ->
        Membrane.Logger.error("Failed to register output stream. Reason: #{reason}")
        {[], state}
    end
  end

  @impl true
  def handle_parent_notification(:start_composing, _ctx, state = %State{}) do
    :ok = VcReq.start_composing()
    {[], state}
  end

  # TODO fix this, it's so awful. Compilation shouldn't take place in handle_init
  @spec start_video_compositor_server() :: :ok | {:error, String.t()}
  defp start_video_compositor_server() do
    :ok = build_process_helper()

    {run_result, run_exit_code} =
      System.cmd("cargo", [
        "run",
        "--manifest-path",
        "./deps/video_compositor/Cargo.toml",
        "-r",
        "--bin",
        "video_compositor"
      ])

    case run_exit_code do
      0 -> :ok
      _else -> {:error, run_result}
    end
  end

  @spec build_process_helper() :: :ok | {:error, String.t()}
  defp build_process_helper() do
    {build_process_helper_result, build_process_helper_exit_code} =
      System.cmd("cargo", [
        "build",
        "--manifest-path",
        "./deps/video_compositor/Cargo.toml",
        "-r",
        "--bin",
        "process_helper"
      ])

    case build_process_helper_exit_code do
      0 -> :ok
      _else -> {:error, build_process_helper_result}
    end
  end

  @spec input_port(non_neg_integer()) :: non_neg_integer()
  defp input_port(input_count) do
    8000 + input_count * 2
  end

  @spec output_port(non_neg_integer()) :: non_neg_integer()
  defp output_port(output_count) do
    8000 + output_count * 2
  end
end
