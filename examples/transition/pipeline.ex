defmodule Membrane.VideoCompositor.Examples.Transition.Pipeline do
  @moduledoc false

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.H264
  alias Membrane.VideoCompositor.{Context, InputState, Resolution}
  alias Req

  @input_resolution %Resolution{width: 1280, height: 720}
  @output_resolution %Resolution{width: 1280, height: 720}

  @impl true
  def handle_init(_ctx, _opt) do
    spec =
      child(:video_compositor, %Membrane.VideoCompositor{
        framerate: 30
      })

    spec_2 = [
      child({:video_src, 0}, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child({:input_parser, 0}, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, 0}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 0), options: [input_id: "input_0"])
      |> get_child(:video_compositor),
      get_child(:video_compositor)
      |> via_out(:output,
        options: [resolution: @output_resolution, output_id: "output"]
      )
      |> child(:output_parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:output_decoder, H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)
    ]

    Process.send_after(self(), :add_input, 5000)

    {[spec: spec, spec: spec_2], %{videos_count: 1}}
  end

  @impl true
  def handle_child_notification(
        {:input_registered, _input_ref, _input_id, ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    {[update_scene_action(ctx)], state}
  end

  @impl true
  def handle_child_notification(
        {:vc_request_response, req, %Req.Response{status: code, body: body}, ctx},
        _child,
        _ctx,
        state
      ) do
    if code != 200 do
      raise("Request failed. Code: #{code}, body: #{inspect(body)}.")
    end

    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_info(:add_input, _ctx, state = %{videos_count: videos_count}) do
    spec =
      child({:video_src, videos_count}, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child({:input_parser, videos_count}, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, videos_count}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, videos_count), options: [input_id: "input_#{videos_count}"])
      |> get_child(:video_compositor)

    {[spec: spec], %{state | videos_count: videos_count + 1}}
  end

  defp update_scene_action(%Context{inputs: inputs}) do
    input_pads = inputs |> Enum.map(fn %InputState{input_id: input_id} -> input_id end)

    update_scene_request_body =
      case length(input_pads) do
        1 ->
          %{
            type: "update_scene",
            nodes: [
              fit(input_pads)
            ],
            outputs: [
              %{
                output_id: "output",
                input_pad: "fitted_input_0"
              }
            ]
          }

        2 ->
          [input_0, input_1] = input_pads
          fitted_pads = [fitted_node_id(input_0), fitted_node_id(input_1)]

          update_scene_request_body =
            %{
              type: "update_scene",
              nodes: [
                fit([input_0]),
                fit([input_1]),
                transition_node(fitted_pads)
              ],
              outputs: [
                %{
                  output_id: "output",
                  input_pad: "layout_transition"
                }
              ]
            }

        _other ->
          raise("Unsupported inputs count!")
      end

    {:notify_child, {:video_compositor, {:vc_request, update_scene_request_body}}}
  end

  defp transition_node(input_pads) do
    %{
      type: "transition",
      node_id: "layout_transition",
      start: start_transition_layouts() |> fixed_position_layout(),
      end: end_transition_layouts() |> fixed_position_layout(),
      transition_duration_ms: 1000,
      interpolation: "linear",
      input_pads: input_pads
    }
  end

  defp fit(input_pads = [input_pad_id]) do
    %{
      type: "built-in",
      node_id: fitted_node_id(input_pad_id),
      transformation: "transform_to_resolution",
      strategy: "fit",
      resolution: %{
        width: @output_resolution.width,
        height: @output_resolution.height
      },
      input_pads: input_pads
    }
  end

  defp fitted_node_id(input_pad_id) do
    "fitted_#{input_pad_id}"
  end

  defp start_transition_layouts() do
    [
      %{
        left: "0px",
        top: "0px"
      },
      %{
        left: "0px",
        top: "0px"
      }
    ]
  end

  defp end_transition_layouts do
    [
      %{
        left: "0%",
        top: "0%"
      },
      %{
        right: "50px",
        top: "50px",
        scale: 0.25
      }
    ]
  end

  defp fixed_position_layout(texture_layouts) do
    %{
      type: "built-in",
      transformation: "fixed_position_layout",
      texture_layouts: texture_layouts,
      resolution: %{
        width: @output_resolution.width,
        height: @output_resolution.height
      }
    }
  end
end
