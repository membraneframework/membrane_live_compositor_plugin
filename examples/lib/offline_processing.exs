defmodule OfflineProcessing do
  @moduledoc false

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.LiveCompositor
  alias Membrane.Hackney
  alias Membrane.LiveCompositor.OutputOptions

  @output_id "output_1"
  @shader_id "shader_1"
  @output_width 1280
  @output_height 720
  @video_url "http://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/big-buck-bunny/bun33s_720x480.h264"
  @shader_path "./lib/example_shader.wgsl"
  @output_file "offline_processing_output.mp4"

  @impl true
  def handle_init(_ctx, %{server_setup: server_setup}) do
    spec =
      child(:media_source, %Hackney.Source{
        location: @video_url,
        hackney_opts: [follow_redirect: true],
        max_retries: 3
      })
      |> child({:input_parser, 0}, %Membrane.H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> via_in(Pad.ref(:input, 0),
        options: [input_id: "input_0", offset: Membrane.Time.seconds(5), required: true]
      )
      |> child(:video_compositor, %LiveCompositor{
        framerate: {30, 1},
        server_setup: server_setup,
        composing_strategy: :ahead_of_time
      })

    {[spec: spec], %{}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    output_opt = %OutputOptions{
      id: @output_id,
      video: %OutputOptions.Video{
        encoder_preset: :ultrafast,
        width: @output_width,
        height: @output_height,
        initial:
          scene([
            %{type: :input_stream, input_id: "input_0", id: "child_0"}
          ])
      }
    }

    schedule_unregister_output = {
      :lc_request,
      %{
        type: :unregister,
        entity_type: :output_stream,
        output_id: @output_id,
        schedule_time_ms: 30_000
      }
    }

    schedule_scene_update_1 = {
      :lc_request,
      %{
        type: :update_output,
        output_id: @output_id,
        video:
          scene([
            %{type: :input_stream, input_id: "input_0", id: "child_0"},
            %{type: :input_stream, input_id: "input_0", id: "child_2"}
          ]),
        schedule_time_ms: 10_000
      }
    }

    schedule_scene_update_2 = {
      :lc_request,
      %{
        type: :update_output,
        output_id: @output_id,
        video:
          scene([
            %{type: :input_stream, input_id: "input_0", id: "child_0"},
            %{type: :input_stream, input_id: "input_0", id: "child_1"},
            %{type: :input_stream, input_id: "input_0", id: "child_2"}
          ]),
        schedule_time_ms: 20_000
      }
    }

    {[
       notify_child: {:video_compositor, {:lc_request, register_shader_request_body()}},
       notify_child: {:video_compositor, {:register_output, output_opt}},
       notify_child: {:video_compositor, schedule_unregister_output},
       notify_child: {:video_compositor, schedule_scene_update_1},
       notify_child: {:video_compositor, schedule_scene_update_2}
     ], state}
  end

  @impl true
  def handle_child_notification(
        {:output_registered, _id, _lc_ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    {[{:notify_child, {:video_compositor, :start_composing}}], state}
  end

  @impl true
  def handle_child_notification(
        {:new_output_stream, output_id, _lc_ctx},
        :video_compositor,
        _membrane_ctx,
        state
      ) do
    spec = [
      get_child(:video_compositor)
      |> via_out(:output,
        options: [output_id: output_id]
      )
      |> child(:output_parser, %Membrane.H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}},
        output_stream_structure: :avc1
      })
      |> child(:muxer, Membrane.MP4.Muxer.ISOM)
      |> child(:sink, %Membrane.File.Sink{location: @output_file})
    ]

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(
        {:lc_request_response, req, %Req.Response{status: response_code, body: response_body},
         _lc_ctx},
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
  def handle_element_end_of_stream(:sink, _pad_ref, _context, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_, _, _context, state) do
    {[], state}
  end

  @spec scene(any()) :: map()
  defp scene(children) do
    %{
      type: :shader,
      shader_id: @shader_id,
      resolution: %{
        width: @output_width,
        height: @output_height
      },
      children: [
        %{
          id: "tiles_0",
          type: :tiles,
          width: @output_width,
          height: @output_height,
          background_color_rgba: "#000088FF",
          transition: %{
            duration_ms: 300
          },
          margin: 10,
          children: children
        }
      ]
    }
  end

  defp register_shader_request_body() do
    %{
      type: :register,
      entity_type: :shader,
      shader_id: @shader_id,
      source: File.read!(@shader_path)
    }
  end
end

server_setup = Utils.LcServer.server_setup({30, 1})

{:ok, supervisor, _pid} =
  Membrane.Pipeline.start_link(OfflineProcessing, %{
    server_setup: server_setup
  })

require Membrane.Logger

Process.monitor(supervisor)

receive do
  msg -> Membrane.Logger.info("Supervisor finished: #{inspect(msg)}")
end
