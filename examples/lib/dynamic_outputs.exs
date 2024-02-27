defmodule DynamicOutputsPipeline do
  @moduledoc false

  # Every 5 seconds add new output stream. After 10 seconds from its creation
  # remove it.

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.LiveCompositor
  alias Membrane.LiveCompositor.{Context, OutputOptions}

  @output_width 1920
  @output_height 1080
  @layout_id "layout"
  @first_output_port 8002

  @impl true
  def handle_init(_ctx, %{sample_path: sample_path, server_setup: server_setup}) do
    spec =
      child(:video_compositor, %Membrane.LiveCompositor{
        framerate: {30, 1},
        server_setup: server_setup
      })

    input_specs = 0..10 |> Enum.map(fn input_number -> input_spec(input_number, sample_path) end)

    0..5
    |> Enum.each(fn output_number ->
      five_seconds = 5_000

      Process.send_after(
        self(),
        {:register_output, output_id(output_number), @first_output_port + output_number},
        output_number * five_seconds
      )
    end)

    {[spec: spec, spec: input_specs], %{sample_path: sample_path, inputs: [], outputs: []}}
  end

  @impl true
  def handle_child_notification(
        {:input_registered, _id, lc_ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    {inputs, outputs} = inputs_outputs_ids(lc_ctx)
    actions = outputs |> Enum.map(fn output_id -> update_scene_action(inputs, output_id) end)
    {actions, %{state | inputs: inputs, outputs: outputs}}
  end

  @impl true
  def handle_child_notification(
        {:output_registered, output_id, lc_ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    {inputs, outputs} = inputs_outputs_ids(lc_ctx)
    {[update_scene_action(inputs, output_id)], %{state | inputs: inputs, outputs: outputs}}
  end

  @impl true
  def handle_child_notification(
        {:new_output_stream, output_id, _lc_ctx},
        :video_compositor,
        _membrane_ctx,
        state
      ) do
    Process.send_after(self(), {:remove_output, output_id}, 10_000)
    {[spec: output_spec(output_id)], state}
  end

  @impl true
  def handle_child_notification(
        {:lc_request_response, req, %Req.Response{status: response_code, body: response_body},
         _lc_ctx},
        :video_compositor,
        _membrane_ctx,
        state
      ) do
    if response_code != 200 do
      raise """
      Request failed.
      Request: `#{inspect(req)}.
      Response code: #{response_code}.
      Response body: #{inspect(response_body)}.
      """
    end

    {[], state}
  end

  @impl true
  def handle_child_notification(notification, child, _ctx, state) do
    Membrane.Logger.debug(
      "Received notification: #{inspect(notification)} from child: #{inspect(child)}."
    )

    {[], state}
  end

  @impl true
  def handle_info({:register_output, output_id, port}, _ctx, state) do
    output_opt = %OutputOptions{
      id: output_id,
      video: %OutputOptions.Video{
        width: @output_width,
        height: @output_height,
        initial: %{type: :view}
      }
    }

    {[notify_child: {:video_compositor, {:register_output, output_opt}}], state}
  end

  @impl true
  def handle_info(
        {:remove_output, output_id},
        _ctx,
        state = %{inputs: inputs, outputs: outputs}
      ) do
    outputs = List.delete(outputs, output_id)

    # Change the scene before removing the output.
    # LiveCompositor forbids removing output used in the current scene.
    {[remove_children: output_group_id(output_id)], %{state | outputs: outputs}}
  end

  @spec update_scene_action(list(LiveCompositor.input_id()), LiveCompositor.output_id()) ::
          Membrane.Pipeline.Action.notify_child()
  defp update_scene_action(input_ids, output_id) do
    update_scene_request = %{
      type: :update_output,
      output_id: output_id,
      video: %{
        type: :tiles,
        padding: 10,
        children:
          input_ids |> Enum.map(fn input_id -> %{type: :input_stream, input_id: input_id} end)
      }
    }

    {:notify_child, {:video_compositor, {:lc_request, update_scene_request}}}
  end

  defp input_spec(input_number, sample_path) do
    child({:video_src, input_number}, %Membrane.File.Source{location: sample_path})
    |> child({:input_parser, input_number}, %Membrane.H264.Parser{
      output_alignment: :nalu,
      generate_best_effort_timestamps: %{framerate: {30, 1}}
    })
    |> child({:realtimer, input_number}, Membrane.Realtimer)
    |> via_in(Pad.ref(:input, input_number), options: [input_id: "input_#{input_number}"])
    |> get_child(:video_compositor)
  end

  defp output_spec(output_id) do
    links =
      get_child(:video_compositor)
      |> via_out(Membrane.Pad.ref(:output, output_id),
        options: [
          output_id: output_id
        ]
      )
      |> child({:output_parser, output_id}, Membrane.H264.Parser)
      |> child({:output_decoder, output_id}, Membrane.H264.FFmpeg.Decoder)
      |> child({:sdl_player, output_id}, Membrane.SDL.Player)

    {links, group: output_group_id(output_id)}
  end

  defp inputs_outputs_ids(%Context{inputs: inputs, outputs: outputs}) do
    input_ids = inputs |> Enum.map(fn %Context.InputStream{id: input_id} -> input_id end)
    output_ids = outputs |> Enum.map(fn %Context.OutputStream{id: output_id} -> output_id end)

    {input_ids, output_ids}
  end

  defp output_id(output_number) do
    "output_#{output_number}"
  end

  defp output_group_id(output_id) do
    "output_group_#{output_id}"
  end
end

Utils.FFmpeg.generate_sample_video()

server_setup = Utils.LcServer.server_setup({30, 1})

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(DynamicOutputsPipeline, %{
    sample_path: "samples/testsrc.h264",
    server_setup: server_setup
  })

Process.sleep(:infinity)
