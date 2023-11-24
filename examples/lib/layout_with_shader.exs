defmodule LayoutWithShaderPipeline do
  @moduledoc false

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.{Context, OutputOptions}

  @output_width 1920
  @output_height 1080
  @output_id "output"
  @shader_path "./lib/example_shader.wgsl"

  @impl true
  def handle_init(_ctx, %{sample_path: sample_path}) do
    spec =
      child({:video_src, 0}, %Membrane.File.Source{location: sample_path})
      |> child({:input_parser, 0}, %Membrane.H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, 0}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, 0), options: [input_id: "input_0"])
      |> child(:video_compositor, %Membrane.VideoCompositor{
        framerate: 30
      })

    {[spec: spec], %{videos_count: 1, sample_path: sample_path}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    output_opt = %OutputOptions{
      width: @output_width,
      height: @output_height,
      id: @output_id
    }

    {[
       start_timer: {:add_videos_timer, Membrane.Time.seconds(3)},
       notify_child: {:video_compositor, {:vc_request, register_shader_request_body()}},
       notify_child: {:video_compositor, {:register_output, output_opt}}
     ], state}
  end

  @impl true
  def handle_child_notification(
        {register, _input_id, compositor_ctx},
        :video_compositor,
        _ctx,
        state
      )
      when register == :input_registered or register == :output_registered do
    {[update_scene_action(compositor_ctx)], state}
  end

  @impl true
  def handle_child_notification(
        {:new_output_stream, output_id, _vc_ctx},
        :video_compositor,
        _membrane_ctx,
        state
      ) do
    spec = [
      get_child(:video_compositor)
      |> via_out(:output,
        options: [output_id: output_id]
      )
      |> child(:output_parser, Membrane.H264.Parser)
      |> child(:output_decoder, Membrane.H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)
    ]

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(
        {:vc_request_response, req, %Req.Response{status: response_code, body: response_body},
         _vc_ctx},
        _child,
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
  def handle_tick(:add_videos_timer, _ctx, state) do
    videos_count = state.videos_count

    if state.videos_count < 10 do
      spec =
        child({:video_src, videos_count}, %Membrane.File.Source{location: state.sample_path})
        |> child({:input_parser, videos_count}, %Membrane.H264.Parser{
          output_alignment: :nalu,
          generate_best_effort_timestamps: %{framerate: {30, 1}}
        })
        |> child({:realtimer, videos_count}, Membrane.Realtimer)
        |> via_in(Pad.ref(:input, videos_count), options: [input_id: "input_#{videos_count}"])
        |> get_child(:video_compositor)

      {[spec: spec], %{state | videos_count: state.videos_count + 1}}
    else
      {[stop_timer: :add_videos_timer], state}
    end
  end

  @spec update_scene_action(Context.t()) :: Membrane.Pipeline.Action.notify_child()
  defp update_scene_action(%Context{outputs: []}) do
    request_body = %{
      type: :update_scene,
      nodes: [],
      outputs: []
    }

    {:notify_child, {:video_compositor, {:vc_request, request_body}}}
  end

  defp update_scene_action(%Context{inputs: inputs, outputs: outputs}) do
    update_scene_request =
      if Enum.empty?(inputs) or Enum.empty?(outputs) do
        empty_scene()
      else
        layout_scene(inputs)
      end

    {:notify_child, {:video_compositor, {:vc_request, update_scene_request}}}
  end

  @spec empty_scene() :: VideoCompositor.request_body()
  defp empty_scene() do
    %{
      type: :update_scene,
      nodes: [],
      outputs: []
    }
  end

  @spec layout_scene(list(Context.InputStream.t())) :: VideoCompositor.request_body()
  defp layout_scene(inputs) do
    input_pads = inputs |> Enum.map(fn %Context.InputStream{id: input_id} -> input_id end)

    %{
      type: :update_scene,
      nodes: [
        %{
          type: "built-in",
          node_id: "tiled_layout",
          transformation: :tiled_layout,
          margin: 10,
          resolution: %{
            width: 1920,
            height: 1080
          },
          input_pads: input_pads
        },
        %{
          type: :shader,
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
          output_id: @output_id,
          input_pad: "twisted_layout"
        }
      ]
    }
  end

  defp register_shader_request_body() do
    %{
      type: :register,
      entity_type: :shader,
      shader_id: "example_shader",
      source: File.read!(@shader_path),
      constraints: [
        %{
          type: "input_count",
          fixed_count: 1
        }
      ]
    }
  end
end

Membrane.VideoCompositor.Examples.Utils.FFmpeg.generate_sample_video()

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(LayoutWithShaderPipeline, %{sample_path: "samples/testsrc.h264"})

Process.sleep(:infinity)
