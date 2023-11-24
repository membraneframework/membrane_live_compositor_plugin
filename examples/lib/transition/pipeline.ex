defmodule Membrane.VideoCompositor.Examples.Transition.Pipeline do
  @moduledoc false

  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.{Context, OutputOptions}

  @output_width 1280
  @output_height 720

  @impl true
  def handle_init(_ctx, %{sample_path: sample_path}) do
    spec =
      child(:video_compositor, %Membrane.VideoCompositor{
        framerate: 30
      })

    Process.send_after(self(), :add_input, 1000)
    Process.send_after(self(), :add_input, 5000)

    {[spec: spec], %{videos_count: 0, sample_path: sample_path}}
  end

  @impl true
  def handle_setup(_ctx, state) do
    output_opt = %OutputOptions{
      id: "output",
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
        :add_input,
        _ctx,
        state = %{videos_count: videos_count, sample_path: sample_path}
      ) do
    spec =
      child({:video_src, videos_count}, %Membrane.File.Source{
        location: sample_path
      })
      |> child({:input_parser, videos_count}, %Membrane.H264.Parser{
        output_alignment: :nalu,
        generate_best_effort_timestamps: %{framerate: {30, 1}}
      })
      |> child({:realtimer, videos_count}, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, videos_count), options: [input_id: "input_#{videos_count}"])
      |> get_child(:video_compositor)

    {[spec: spec], %{state | videos_count: videos_count + 1}}
  end

  @spec new_scene_request(Context.t()) :: :no_update | VideoCompositor.request_body()
  defp new_scene_request(%Context{
         inputs: [%Context.InputStream{id: input_id}],
         outputs: [%Context.OutputStream{id: output_id}]
       }) do
    {fit_node, fit_node_id} = fit(input_id)

    %{
      type: :update_scene,
      nodes: [fit_node],
      outputs: [
        %{
          output_id: output_id,
          input_pad: fit_node_id
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
    {first_fit_node, first_fit_node_id} = fit(first_input_id)
    {second_fit_node, second_fit_node_id} = fit(second_input_id)
    {transition_node, transition_node_id} = transition([first_fit_node_id, second_fit_node_id])

    %{
      type: :update_scene,
      nodes: [first_fit_node, second_fit_node, transition_node],
      outputs: [
        %{
          output_id: output_id,
          input_pad: transition_node_id
        }
      ]
    }
  end

  defp new_scene_request(_ctx) do
    :no_update
  end

  defp transition(input_pads) do
    transition_node_id = "layout_transition"

    {%{
       type: :transition,
       node_id: transition_node_id,
       start: start_transition_layouts() |> fixed_position_layout(),
       end: end_transition_layouts() |> fixed_position_layout(),
       transition_duration_ms: 1000,
       interpolation: :linear,
       input_pads: input_pads
     }, transition_node_id}
  end

  defp fit(input_pad_id) do
    fit_node_id = "fitted_#{input_pad_id}"

    {%{
       type: "built-in",
       node_id: fit_node_id,
       transformation: :transform_to_resolution,
       strategy: :fit,
       resolution: %{
         width: @output_width,
         height: @output_height
       },
       input_pads: [input_pad_id]
     }, fit_node_id}
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
      transformation: :fixed_position_layout,
      texture_layouts: texture_layouts,
      resolution: %{
        width: @output_width,
        height: @output_height
      }
    }
  end
end
