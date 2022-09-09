defmodule Membrane.VideoCompositor.Pipeline.Utility.NoOp do
  @moduledoc """
  Simple pass by Membrane element. It should have no side effects on the pipeline.
  """
  use Membrane.Filter

  def_input_pad :input, demand_unit: :buffers, caps: :any, demand_mode: :auto
  def_output_pad :output, demand_unit: :buffers, caps: :any, demand_mode: :auto

  @impl true
  def handle_init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, buffer: {:output, buffer}}, state}
  end
end
