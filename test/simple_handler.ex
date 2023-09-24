defmodule Membrane.VideoCompositor.SimpleHandler do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Handler

  alias Membrane.VideoCompositor.Scene

  @impl true
  def handle_pads_change(inputs, outputs, state) do
    tailed_layout = %{
      node_id: "layout",
      type: "built-in",
      transformation: "tailed_layout",
      margin: 10,
      resolution: %{
        width: 1920,
        height: 1080
      },
      input_pads: inputs
    }

    outputs = Enum.map(outputs, fn output_id -> %{output_id: output_id, input_pad: "layout"} end)

    {:update_scene, %Scene{nodes: [tailed_layout], outputs: outputs}, state}
  end
end
