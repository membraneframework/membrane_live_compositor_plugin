defmodule TransitionPipeline do
  @moduledoc false

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.{Context, OutputOptions}

  @output_width 1280
  @output_height 720
  @framerate 30
  @output_id "output"
  @rescaler_id "rescaler"

  @impl true
  def handle_init(_ctx, %{sample_path: sample_path, vc_server_config: vc_server_config}) do
    spec =
      child(:video_compositor, %Membrane.VideoCompositor{
        framerate: @framerate,
        vc_server_config: vc_server_config
      })

    Process.send_after(self(), {:add_input, 0}, 1000)
    Process.send_after(self(), {:add_input, 1}, 5000)

    {[spec: spec], %{sample_path: sample_path}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    output_opt = %OutputOptions{
      id: @output_id,
      width: @output_width,
      height: @output_height
    }

    register_output_msg = {:register_output, output_opt}
    {[notify_child: {:video_compositor, register_output_msg}], state}
  end

  @impl true
  def handle_child_notification(
        {register, _id, vc_ctx},
        :video_compositor,
        _ctx,
        state
      )
      when register == :input_registered or register == :output_registered do
    actions =
      case new_scene_request(vc_ctx) do
        :no_update -> []
        new_scene_request -> [notify_child: {:video_compositor, {:vc_request, new_scene_request}}]
      end

    {actions, state}
  end

  @impl true
  def handle_child_notification(
        {:vc_request_response, req, %Req.Response{status: response_code, body: response_body},
         _vc_ctx},
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
        {:new_output_stream, output_id, _vc_ctx},
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

  @spec new_scene_request(Context.t()) :: :no_update | VideoCompositor.request_body()
  defp new_scene_request(%Context{
         inputs: [%Context.InputStream{id: input_id}],
         outputs: [%Context.OutputStream{id: output_id}]
       }) do
    %{
      type: :update_scene,
      outputs: [
        %{
          output_id: output_id,
          root: single_input_scene(input_id)
        }
      ]
    }
  end

  defp new_scene_request(%Context{
         inputs: [
           %Context.InputStream{id: first_input_id}
           | [%Context.InputStream{id: second_input_id}]
         ],
         outputs: [%Context.OutputStream{id: output_id}]
       }) do
    %{
      type: :update_scene,
      outputs: [
        %{
          output_id: output_id,
          root: double_inputs_scene(first_input_id, second_input_id)
        }
      ]
    }
  end

  defp new_scene_request(_vc_ctx) do
    :no_update
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

Examples.Utils.FFmpeg.generate_sample_video()

vc_server_config = Utils.VcServer.vc_server_config(30)

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(TransitionPipeline, %{
    sample_path: "samples/testsrc.h264",
    vc_server_config: vc_server_config
  })

Process.sleep(:infinity)
