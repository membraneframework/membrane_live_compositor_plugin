defmodule Membrane.VideoCompositor.QueueingStrategy do
  @moduledoc """
  Defines possible VideoCompositor frames queueing strategies.

  Any queuing strategy should follow contracts defined in `#{inspect(Queue)}` module.
  """

  defmodule Offline do
    @moduledoc """
    Offline queueing strategy, suitable for non real-time processing.
    Always await for frames form input pads.
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

    @type latency :: Membrane.Time.non_neg_t() | :wait_for_start_event
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

  @type t :: Offline | Live.t()
end
