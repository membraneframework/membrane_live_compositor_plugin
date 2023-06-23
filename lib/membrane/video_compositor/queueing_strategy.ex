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
    Produces frames in stable periods.
    """

    @enforce_keys [:latency]
    defstruct @enforce_keys

    @typedoc """
    Latency specifies when VideoCompositor will start producing frames.

    Latency can be set to:
      - `t:Membrane.Time.non_neg_integer()` - a fixed time, after which VC will start composing frames,
        Setting latency to a higher value allows VideoCompositor to await longer for input frames,
        but results in higher output stream latency and RAM usage.
      - `:wait_for_start_event` value, which awaits for `t:start_timer_message()` to trigger / schedule composing.
        Be aware that VC enqueues all received frames, so not sending `t:start_timer_message()` / sending it late, will
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
    Latency is time period after which, VideoCompositor will start producing frames.
    It doesn't modify output frames pts.
    Setting latency to higher value allows VideoCompositor to await longer for input frames,
    but results in higher output stream latency and RAM usage.
    User can also trigger composition with Elixir message, by setting `latency` to `:wait_for_start_event`
    and sending `t:start_timer_message()`.
    """
    @type t :: %__MODULE__{
            latency: latency()
          }
  end

  @type t :: Offline.t() | Live.t()
end
