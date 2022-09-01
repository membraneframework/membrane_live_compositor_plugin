defmodule Membrane.VideoCompositor.Test.Pipeline.Raw do
  @moduledoc """
  Pipeline for testing simple composing of two videos, by placing one above the other.
  """

  use Membrane.Pipeline

  @doc """
  handle_init(%{
      paths: %{
        first_video_path: String.t(),
        second_video_path: String.t(),
        output_path: String.t()
      },
      caps: RawVideo,
      implementation: :ffmpeg | :opengl | :nx
  })
  """
  @impl true
  def handle_init(options) do
    caps = options.caps

    parser = %Membrane.RawVideo.Parser{
      framerate: caps.framerate,
      width: caps.width,
      height: caps.height,
      pixel_format: caps.pixel_format
    }

    options = Map.put(options, :decoder, parser)

    options =
      Map.put_new(options, :compositor, %Membrane.VideoCompositor{
        implementation: options.implementation,
        caps: options.caps
      })

    Membrane.VideoCompositor.Pipeline.ComposeTwoInputs.handle_init(options)
  end

  @impl true
  def handle_element_end_of_stream({pad, ref}, context, state) do
    Membrane.VideoCompositor.Pipeline.ComposeTwoInputs.handle_element_end_of_stream(
      {pad, ref},
      context,
      state
    )
  end
end
