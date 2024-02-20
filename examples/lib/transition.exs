defmodule TransitionPipeline do
  @moduledoc false

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.LiveCompositor
  alias Membrane.LiveCompositor.{Context, OutputOptions}

  @output_width 1280
  @output_height 720
  @output_id "output"
  @rescaler_id "rescaler"

  @impl true
  def handle_init(_ctx, %{sample_path: sample_path, server_setup: server_setup}) do
    spec =
      child(:video_compositor, %Membrane.LiveCompositor{
        framerate: {30, 1},
        server_setup: server_setup
      })

    Process.send_after(self(), {:add_input, 0}, 1000)
    Process.send_after(self(), {:add_input, 1}, 5000)

    {[spec: spec], %{sample_path: sample_path}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    output_opt = %OutputOptions{
      id: @output_id,
      video: %OutputOptions.Video{
          width: @output_width,
          height: @output_height,
          initial: %{type: :view}
      }
    }

    register_output_msg = {:register_output, output_opt}
    {[notify_child: {:video_compositor, register_output_msg}], state}
  end

  @impl true
  def handle_child_notification(
        {:input_registered, _id, lc_ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    actions =
      lc_ctx.outputs
      |> Enum.map(fn output ->
        {:notify_child,
         {:video_compositor, {:lc_request, new_scene_request(lc_ctx.inputs, output.id)}}}
      end)

    {actions, state}
  end

  @impl true
  def handle_child_notification(
        {:output_registered, output_id, lc_ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    {[
       notify_child:
         {:video_compositor, {:lc_request, new_scene_request(lc_ctx.inputs, output_id)}}
     ], state}
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
  def handle_child_notification(
        {:new_output_stream, output_id, _lc_ctx},
        :video_compositor,
        _ctx,
        state
      ) do
    spec =
      get_child(:video_compositor)
      |> via_out(:output,
        options: [output_id: output_id]
      )
      |> child(:output_parser, Membrane.H264.Parser)
      |> child(:output_decoder, Membrane.H264.FFmpeg.Decoder)
      |> child(:sdl_player, Membrane.SDL.Player)

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_info(
        {:add_input, input_num},
        _ctx,
        state = %{sample_path: sample_path}
      ) do
    spec =
      child({:video_src, input_num}, %Membrane.File.Source{
        location: sample_path
      })
      |> child({:input_parser, input_num}, %Membrane.H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, input_num}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, input_num), options: [input_id: input_id(input_num)])
      |> get_child(:video_compositor)

    {[spec: spec], state}
  end

  @spec new_scene_request(list(Context.InputStream.t()), LiveCompositor.output_id()) ::
          :no_update | LiveCompositor.request_body()
  defp new_scene_request([%Context.InputStream{id: input_id}], output_id) do
    %{
      type: :update_output,
      output_id: output_id,
      video: single_input_scene(input_id)
    }
  end

  defp new_scene_request(
         [
           %Context.InputStream{id: first_input_id} | [%Context.InputStream{id: second_input_id}]
         ],
         output_id
       ) do
    %{
      type: :update_output,
      output_id: output_id,
      video: double_inputs_scene(first_input_id, second_input_id)
    }
  end

  defp new_scene_request(_lc_ctx, output_id) do
    %{
      type: :update_output,
      output_id: output_id,
      video: %{type: :view, children: []}
    }
  end

  defp single_input_scene(input_id) do
    %{
      type: :view,
      children: [
        %{
          type: :rescaler,
          mode: :fit,
          id: @rescaler_id,
          top: 0,
          right: 0,
          width: @output_width,
          height: @output_height,
          transition: %{
            duration_ms: 1000
          },
          child: %{
            type: :input_stream,
            input_id: input_id
          }
        }
      ]
    }
  end

  defp double_inputs_scene(first_input_id, second_input_id) do
    %{
      type: :view,
      children: [
        %{
          type: :rescaler,
          mode: :fit,
          child: %{
            type: :input_stream,
            input_id: second_input_id
          }
        },
        %{
          type: :rescaler,
          mode: :fit,
          id: @rescaler_id,
          top: 10,
          right: 10,
          width: div(@output_width, 3),
          height: div(@output_height, 3),
          transition: %{
            duration_ms: 1000
          },
          child: %{
            type: :input_stream,
            input_id: first_input_id
          }
        }
      ]
    }
  end

  defp input_id(input_num) do
    "input_#{input_num}"
  end
end

Utils.FFmpeg.generate_sample_video()

server_setup = Utils.LcServer.server_setup({30, 1})

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(TransitionPipeline, %{
    sample_path: "samples/testsrc.h264",
    server_setup: server_setup
  })

Process.sleep(:infinity)
