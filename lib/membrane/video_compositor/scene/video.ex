defmodule Membrane.VideoCompositor.Scene.Video do
  @moduledoc """
  Properties and transformations of the video.
  """
  alias Membrane.VideoCompositor.Scene.Transformation

  @type t :: %__MODULE__{
          position: %Membrane.VideoCompositor.Position{}
        }
  @enforce_keys [:position]
  defstruct position: nil, transformations: []

  @spec update(__MODULE__.t(), number()) :: __MODULE__.t()
  def update(video, time) do
    case Transformation.update_all(video, video.transformations, time) do
      {:ok, {video, transformations}} ->
        {:ok, %__MODULE__{video | transformations: transformations}}

      {:error, error} ->
        {:error, error}
    end
  end
end
