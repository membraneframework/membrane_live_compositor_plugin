defmodule Membrane.VideoCompositor.Scene.Video do
  @moduledoc """
  Properties and transformations of the video.
  """
  alias Membrane.VideoCompositor.Scene.Transformation

  @type error_t :: any()

  @type t :: %__MODULE__{
          position: Membrane.VideoCompositor.Position.t(),
          transformations: keyword(Transformation.t()),
          components: %{required(atom) => any()}
        }
  @enforce_keys [:position]
  defstruct position: nil, transformations: [], components: %{}

  @spec update(__MODULE__.t(), number()) :: {:ok, __MODULE__.t()} | {:error, error_t()}
  def update(video, time) do
    case Transformation.update_all(video, video.transformations, time) do
      {:ok, {video, transformations}} ->
        {:ok, %__MODULE__{video | transformations: transformations}}

      {:error, error} ->
        {:error, error}
    end
  end
end
