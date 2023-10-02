defmodule Membrane.VideoCompositor.SimpleHandler do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Handler

  alias Membrane.VideoCompositor.Scene

  @impl true
  def handle_pads_change(ctx, state) do
    if length(ctx.outputs) > 0 do
      input_pads = Enum.map(ctx.inputs, fn input_ctx -> input_ctx.input_id end)

      tailed_layout = %{
        node_id: "layout",
        type: "built-in",
        transformation: "tiled_layout",
        margin: 10,
        resolution: %{
          width: 1280,
          height: 720
        },
        input_pads: input_pads
      }

      outputs =
        Enum.map(ctx.outputs, fn output_ctx ->
          %{output_id: output_ctx.output_id, input_pad: "layout"}
        end)

      {:update_scene, %Scene{nodes: [tailed_layout], outputs: outputs}, state}
    else
      state
    end
  end

  @impl true
  def handle_info(_msg, _ctx, state) do
    state
  end
end
