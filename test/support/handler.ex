defmodule Membrane.VideoCompositor.Support.Handler do
  @moduledoc """
  Simple VideoCompositor handler setting scene from video configs passed in metadata fields.
  """

  @behaviour Membrane.VideoCompositor.Handler

  alias Membrane.VideoCompositor.Handler.Inputs.InputProperties
  alias Membrane.VideoCompositor.Scene

  @impl true
  def handle_init(_options) do
    nil
  end

  @impl true
  def handle_inputs_change(inputs, _ctx, state) do
    inputs
    |> Enum.map(fn {pad, %InputProperties{metadata: video_config}} ->
      {pad, video_config}
    end)
    |> Enum.into(%{})
    |> then(fn video_configs -> {%Scene{video_configs: video_configs}, state} end)
  end

  @impl true
  def handle_info(_msg, ctx, state) do
    {ctx.scene, state}
  end
end
