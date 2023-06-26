defmodule Membrane.VideoCompositor.QueueingStrategy do
  @moduledoc """
  Defines possible VideoCompositor frames and events queueing strategies.
  """

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
    compose frames from every input stream with the smallest pts difference to output frame pts.
    """

    @enforce_keys [:latency]
    defstruct @enforce_keys

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
    Specify the message that triggers/schedule the start of VC composing.

    ## Values:
      - After receiving `:start_timer` message, VC will immediately start composing.
      - After receiving `{:start_timer, delay :: Membrane.Time.non_neg_t()}`, VC will start composing after
        the time specified by `delay`
    """
    @type start_timer_message :: :start_timer | {:start_timer, delay :: Membrane.Time.non_neg_t()}

    @typedoc """
    Describe parameters of live queueing strategy.

    For more information, view: `t:latency/0`
    """
    @type t :: %__MODULE__{
            latency: latency()
          }
  end

  @typedoc """
  Defines possible queueing strategies.

  For specific strategy description, view:
    - `#{inspect(Live)}`
    - `#{inspect(Offline)}`
  """
  @type t :: Offline.t() | Live.t()
end
