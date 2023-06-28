defmodule Membrane.VideoCompositor.Queue.Strategy.Live.State do
  @moduledoc false

  alias Membrane.VideoCompositor.Queue.Strategy.Live

  @enforce_keys [:latency, :eos_strategy]
  defstruct @enforce_keys ++
              [timer_started?: false, started_playing?: false, eos_scheduled?: false]

  @type t :: %__MODULE__{
          latency: Live.latency(),
          eos_strategy: Membrane.VideoCompositor.QueueingStrategy.Live.eos_strategy(),
          started_playing?: boolean(),
          eos_scheduled?: boolean(),
          timer_started?: boolean()
        }
end
