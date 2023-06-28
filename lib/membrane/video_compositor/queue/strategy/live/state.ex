defmodule Membrane.VideoCompositor.Queue.Strategy.Live.State do
  @moduledoc false

  alias Membrane.VideoCompositor.Queue.Strategy.Live

  @enforce_keys [:latency]
  defstruct @enforce_keys ++ [timer_started?: false]

  @type t :: %__MODULE__{
          latency: Live.latency(),
          timer_started?: boolean()
        }
end
