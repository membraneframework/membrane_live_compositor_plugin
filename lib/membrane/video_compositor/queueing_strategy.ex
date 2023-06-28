defmodule Membrane.VideoCompositor.QueueingStrategy do
  @moduledoc """
  Defines possible VideoCompositor frames and events queueing strategies.
  """

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Queue.Strategies.Live, as: LiveQueue
  alias Membrane.VideoCompositor.Queue.Strategies.Offline, as: OfflineQueue

  defmodule Offline do
    @moduledoc """
    Offline queueing strategy, suitable for non-real-time processing.

    In this strategy frames are sent to the compositor only when all added input pads queues,
    with timestamp offset lower or equal to composed buffer pts,
    have at least one frame.
    """

    @type t :: __MODULE__
  end

  defmodule Live do
    @moduledoc """
    Live queueing strategy, suitable for real-time processing, like live streams.

    Every `1 / output fps` seconds after start of composition (view `t:latency/0`)
    composes frames from every input stream with the smallest pts difference to output frame pts.
    """

    @enforce_keys [:latency]
    defstruct @enforce_keys ++ [eos_strategy: :all_inputs_eos]

    @typedoc """
    Latency specifies when VideoCompositor will start producing frames.

    Latency can be set to:
      - `t:Membrane.Time.non_neg_t/0` - a fixed time, after which VC will start composing frames,
        Setting latency to a higher value allows VideoCompositor to await longer for input frames,
        but results in higher output stream latency and RAM usage.
      - `:wait_for_start_event` value, which awaits for `t:start_timer_message/0` to trigger / schedule composing.
        Be aware that VC enqueues all received frames, so not sending `t:start_timer_message/0` / sending it late, will
        result in high RAM usage.

    It doesn't modify output frames pts.
    """
    @type latency :: Membrane.Time.non_neg_t() | :wait_for_start_event

    @typedoc """
    Specifies the message that triggers/schedule the start of VC composing.

    ## Values:
      - After receiving `:start_timer` message, VC will immediately start composing.
      - After receiving `{:start_timer, delay :: Membrane.Time.non_neg_t()}`, VC will start composing after
        the time specified by `delay`
    """
    @type start_timer_message :: :start_timer | {:start_timer, delay :: Membrane.Time.non_neg_t()}

    @typedoc """
    Specifies possible strategies for VideoCompositor to send `t:Membrane.Element.Action.end_of_stream_t/0`.

    ## Strategies:
    - In the `:all_inputs_eos` strategy VideoCompositor sends EOS after receiving EOSs from all input pads.
    - In the `:schedule_eos` strategy VideoCompositor sends EOS after receiving `t:schedule_eos_message/0` and EOSs
      from all input pads.
      If all input pads sent EOS and VideoCompositor hasn't received the `t:schedule_eos_message/0` message,
      VC will produce frames black frames until it receives the `t:schedule_eos_message/0` message.
      This is useful, when e.g. some peer connects to a VideoCompositor via the live streaming application. His connection
      can be dropped and restored multiple times. With this strategy, user can control when VC should send EOS.
    """
    @type eos_strategy :: :all_inputs_eos | :schedule_eos

    @typedoc """
    Specifies how message scheduling EOS should look like.

    For more information on scheduling EOS see: `t:eos_strategy/0`.
    """
    @type schedule_eos_message :: :schedule_eos

    @typedoc """
    Describes parameters of live queueing strategy.

    For more information, view: `t:latency/0`
    """
    @type t :: %__MODULE__{
            latency: latency(),
            eos_strategy: eos_strategy()
          }
  end

  @typedoc """
  Defines possible queueing strategies.

  For specific strategy description, view:
    - `#{inspect(Live)}`
    - `#{inspect(Offline)}`
  """
  @type t :: Offline.t() | Live.t()

  @doc false
  @spec get_queue(VideoCompositor.init_options()) :: OfflineQueue.t()
  def get_queue(options = %VideoCompositor{}) do
    case options.queuing_strategy do
      __MODULE__.Offline ->
        %OfflineQueue{vc_init_options: options}

      %__MODULE__.Live{latency: latency} ->
        %LiveQueue{vc_init_options: options, latency: latency}
    end
  end
end
