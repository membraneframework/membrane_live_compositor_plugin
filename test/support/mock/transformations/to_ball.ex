defmodule Membrane.VideoCompositor.Mock.Transformations.ToBall do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Scene.Transformation

  @impl true
  def encode(_rotate) do
    314
  end
end
