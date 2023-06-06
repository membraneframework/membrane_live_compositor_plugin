defmodule Membrane.VideoCompositor.Queue.Live.State do
  @moduledoc false

  alias Membrane.VideoCompositor.Queue.Live

  @enforce_keys [:latency]
  defstruct @enforce_keys ++ [timer_started?: false]

  @type t :: %__MODULE__{
          latency: Live.latency(),
          timer_started?: boolean()
        }
end
