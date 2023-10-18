defmodule Membrane.VideoCompositor.LayoutWithShaderExample.Pipeline do
  @moduledoc false
  
  use Membrane.Pipeline

  require Membrane.Logger
  
  alias Membrane.H264
  alias Membrane.VideoCompositor.{Context, InputState, Resolution}
  alias Req

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
        options: [resolution: %Resolution{width: 1920, height: 1080}, output_id: "output_1"]
      )
      |> child(:output_parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child(:output_decoder, H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)
    ]

    Process.send_after(self(), :register_shader, 10)
    Process.send_after(self(), :add_input, 5000)
    Process.send_after(self(), :add_input, 10_000)
    Process.send_after(self(), :add_input, 15_000)
    Process.send_after(self(), :add_input, 20_000)

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
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_info(:register_shader, _ctx, state) do
    {[register_shader_action()], state}
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

    request_body = %{
      type: "update_scene",
      nodes: [
        %{
          type: "built-in",
          node_id: "tiled_layout",
          transformation: "tiled_layout",
          margin: 10,
          resolution: %{
            width: 1920,
            height: 1080
          },
          input_pads: input_pads
        },
        %{
          type: "shader",
          node_id: "twisted_layout",
          shader_id: "example_shader",
          resolution: %{
            width: 1920,
            height: 1080
          },
          input_pads: ["tiled_layout"]
        }
      ],
      outputs: [
        %{
          output_id: "output_1",
          input_pad: "twisted_layout"
        }
      ]
    }

    {:notify_child, {:video_compositor, {:vc_request, request_body}}}
  end

  defp register_shader_action() do
    request_body = %{
      type: "register",
      entity_type: "shader",
      shader_id: "example_shader",
      source: File.read!("./examples/layout_with_shader/example_shader.wgsl")
    }

    {:notify_child, {:video_compositor, {:vc_request, request_body}}}
  end
end
