defmodule Membrane.VideoCompositor.Pipeline do
  @moduledoc false

  use Membrane.Pipeline

  alias Membrane.H264
  alias Membrane.VideoCompositor.{Context, Resolution}

  @impl true
  def handle_init(_ctx, _opt) do
    spec = [
      # VideoCompositor
      child(:video_compositor, %Membrane.VideoCompositor{
        framerate: 30
      }),
      # First input
      child({:video_src, 1}, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child({:input_parser, 1}, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, 1}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 1), options: [input_id: "input_1"])
      |> get_child(:video_compositor),
      # Second input
      child({:video_src, 2}, %Membrane.File.Source{
        location: "samples/testsrc.h264"
      })
      |> child({:input_parser, 2}, %H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, 2}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 2), options: [input_id: "input_2"])
      |> get_child(:video_compositor)
    ]

    # output have to be added after init of VideoCompositor
    spec_2 =
      get_child(:video_compositor)
      |> via_out(:output,
        options: [resolution: %Resolution{width: 1280, height: 720}, output_id: "output_1"]
      )
      |> child(:output_parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:output_decoder, H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)

    {[spec: spec, spec: spec_2], %{}}
  end

  @impl true
  def handle_child_notification(
        {:input_registered, _input_ref, _input_id, ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    case maybe_update_scene(ctx) do
      nil ->
        {[], state}

      scene_request_body ->
        {[notify_child: {:video_compositor, {:vc_request, scene_request_body}}], state}
    end
  end

  @impl true
  def handle_child_notification(
        {:output_registered, _output_ref, _output_id, ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    case maybe_update_scene(ctx) do
      nil ->
        {[], state}

      scene_request_body ->
        {[notify_child: {:video_compositor, {:vc_request, scene_request_body}}], state}
    end
  end

  @impl true
  def handle_child_notification(notification, :video_compositor, _ctx, state) do
    IO.inspect(notification)
    {[], state}
  end

  @spec maybe_update_scene(Context.t()) :: nil | map()
  defp maybe_update_scene(%Context{inputs: inputs, outputs: outputs}) do
    if length(inputs) == 2 and length(outputs) == 1 do
      %{
        type: "update_scene",
        nodes: [
          %{
            type: "built-in",
            node_id: "tiled_layout",
            transformation: "tiled_layout",
            resolution: %{
              width: 1280,
              height: 720
            },
            input_pads: ["input_1", "input_2"]
          }
        ],
        outputs: [
          %{
            output_id: "output_1",
            input_pad: "tiled_layout"
          }
        ]
      }
    else
      nil
    end
  end
end
