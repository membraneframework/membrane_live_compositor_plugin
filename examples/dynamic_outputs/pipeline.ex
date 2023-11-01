# defmodule Membrane.VideoCompositor.Examples.DynamicOutputs.Pipeline do
#   @moduledoc false

#   use Membrane.Pipeline

#   require Membrane.Logger

#   alias Membrane.VideoCompositor.Resolution

#   @impl true
#   def handle_init(_ctx, %{sample_path: sample_path}) do
#     spec =
#       child(:video_compositor, %Membrane.VideoCompositor{
#         framerate: 30
#       })

#     input_specs = 0..10 |> Enum.map(fn input_number -> input_spec(input_number, sample_path) end)

#     0..5
#     |> Enum.map(fn output_number ->
#       five_seconds = 5_000
#       Process.send_after(self(), {:add_output, output_number}, output_number * five_seconds)
#     end)

#     {[spec: spec, spec: input_specs],
#      %{videos_count: 1, sample_path: sample_path, inputs: [], outputs: []}}
#   end

#   @impl true
#   def handle_child_notification(
#         {:input_registered, _ref, input_id, _compositor_ctx},
#         :video_compositor,
#         _ctx,
#         state = %{inputs: inputs, outputs: outputs}
#       ) do
#     inputs = [input_id | inputs]

#     {update_scene_action(inputs, outputs), %{state | inputs: inputs}}
#   end

#   @impl true
#   def handle_child_notification(
#         {:output_registered, _ref, output_id, _compositor_ctx},
#         :video_compositor,
#         _ctx,
#         state = %{inputs: inputs, outputs: outputs}
#       ) do
#     outputs = [output_id | outputs]

#     {update_scene_action(inputs, outputs), %{state | outputs: outputs}}
#   end

#   @impl true
#   def handle_child_notification(
#         {:vc_request_response, _req, %Req.Response{status: code, body: body}, _vc_ctx},
#         :video_compositor,
#         _membrane_ctx,
#         state
#       ) do
#     if code != 200 do
#       raise "Request failed. Code: #{code}, body: #{inspect(body)}."
#     end

#     {[], state}
#   end

#   @impl true
#   def handle_child_notification(notification, child, _ctx, state) do
#     Membrane.Logger.info(
#       "Received notification: #{inspect(notification)} from child: #{inspect(child)}."
#     )

#     {[], state}
#   end

#   @impl true
#   def handle_info({:add_output, output_number}, _ctx, state) do
#     Process.send_after(self(), {:remove_output, output_number}, 10_000)
#     {[spec: output_spec(output_number)], state}
#   end

#   @impl true
#   def handle_info(
#         {:remove_output, output_number},
#         _ctx,
#         state = %{inputs: inputs, outputs: outputs}
#       ) do
#     outputs = outputs |> Enum.reject(fn output_id -> output_id == output_id(output_number) end)

#     children = [
#       {:output_parser, output_number},
#       {:output_decoder, output_number},
#       {:sdl_player, output_number}
#     ]

#     # Change the scene before removing the output.
#     # VideoCompositor forbids removing output used in the current scene.
#     {update_scene_action(inputs, outputs) ++ [remove_children: children],
#      %{state | outputs: outputs}}
#   end

#   defp update_scene_action(inputs, outputs) do
#     outputs =
#       outputs |> Enum.map(fn output_id -> %{output_id: output_id, input_pad: "layout"} end)

#     {nodes, outputs} =
#       if length(outputs) > 0 do
#         {[tiled_layout(inputs)], outputs}
#       else
#         {[], []}
#       end

#     request_body = %{
#       type: "update_scene",
#       nodes: nodes,
#       outputs: outputs
#     }

#     [{:notify_child, {:video_compositor, {:vc_request, request_body}}}]
#   end

#   defp tiled_layout(input_pads) do
#     %{
#       type: "built-in",
#       transformation: "tiled_layout",
#       node_id: "layout",
#       margin: 10,
#       resolution: %{
#         width: 1920,
#         height: 1080
#       },
#       input_pads: input_pads
#     }
#   end

#   defp input_spec(input_number, sample_path) do
#     child({:video_src, input_number}, %Membrane.File.Source{location: sample_path})
#     |> child({:input_parser, input_number}, %Membrane.H264.Parser{
#       output_alignment: :nalu,
#       generate_best_effort_timestamps: %{framerate: {30, 1}}
#     })
#     |> child({:realtimer, input_number}, Membrane.Realtimer)
#     |> via_in(Pad.ref(:input, input_number), options: [input_id: "input_#{input_number}"])
#     |> get_child(:video_compositor)
#   end

#   defp output_spec(output_number) do
#     get_child(:video_compositor)
#     |> via_out(Membrane.Pad.ref(:output, output_number),
#       options: [
#         resolution: %Resolution{width: 1920, height: 1080},
#         output_id: output_id(output_number)
#       ]
#     )
#     |> child({:output_parser, output_number}, Membrane.H264.Parser)
#     |> child({:output_decoder, output_number}, Membrane.H264.FFmpeg.Decoder)
#     |> child({:sdl_player, output_number}, Membrane.SDL.Player)
#   end

#   defp output_id(output_number) do
#     "output_#{output_number}"
#   end
# end
