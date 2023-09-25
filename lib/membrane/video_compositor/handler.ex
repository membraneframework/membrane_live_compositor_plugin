defmodule Membrane.VideoCompositor.Handler do
  @moduledoc false

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Scene

  defmodule Context do
    @moduledoc false

    defstruct [:inputs, :outputs]

    @type input_context :: %{
            input_id: VideoCompositor.input_id(),
            pad_id: Membrane.Pad.ref()
          }

    @type output_context :: %{
            output_id: VideoCompositor.output_id(),
            pad_id: Membrane.Pad.ref()
          }

    @type t :: %__MODULE__{
            inputs: list(input_context),
            outputs: list(output_context)
          }
  end

  @typedoc """
  Module implementing `#{__MODULE__}` behaviour.
  """
  @type t :: module()

  @typedoc """
  User handler state, doesn't affect VideoCompositor behaviour.
  """
  @type handler_state :: any()

  @callback handle_pads_change(
              ctx :: __MODULE__.Context,
              state :: handler_state()
            ) ::
              {:update_scene, Scene.t(), handler_state()} | handler_state()
  # TODO handle info / message callback
end
