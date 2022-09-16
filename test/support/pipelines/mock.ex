defmodule Membrane.VideoCompositor.Test.Support.Pipeline.Mock do
  @moduledoc """
  Pipeline for testing core functionalities of VideoCompositor. Uses mock frame composer.
  """

  import Membrane.ParentSpec

  alias Membrane.RawVideo
  alias Membrane.Testing
  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Test.Support.Mock.FrameComposer, as: MockFrameComposer

  @no_video %RawVideo{
    width: 0,
    height: 0,
    framerate: {0, 1},
    pixel_format: :I420,
    aligned: false
  }

  @doc """
  Starts testing pipeline with sources corresponding to the `inputs` lists of input strings, and merging them using string concatenation.
  """
  @spec start_multi_input_pipeline([[String.t()]]) :: {:ok, pid()}
  def start_multi_input_pipeline(inputs) do
    source_children =
      for {input, i} <- Enum.with_index(inputs),
          do: {String.to_atom("source_#{i}"), %Testing.Source{output: input, caps: @no_video}}

    source_links =
      source_children
      |> Enum.map(fn {source_id, _element} -> link(source_id) |> to(:composer) end)

    children =
      source_children ++
        [
          composer: %VideoCompositor{
            implementation: {:mock, MockFrameComposer},
            caps: @no_video
          },
          sink: Testing.Sink
        ]

    links =
      source_links ++
        [
          link(:composer) |> to(:sink)
        ]

    Testing.Pipeline.start_link(children: children, links: links)
  end
end
