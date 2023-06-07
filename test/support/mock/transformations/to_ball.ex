defmodule Membrane.VideoCompositor.Mock.Transformations.ToBall do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Transformation

  @impl true
  def encode(_rotate) do
    {0xDEADBEEF, 0xDEADBEEF}
  end

  @impl true
  def initialize(_wgpu_ctx) do
    {0xDEADBEEF, 0xDEADBEEF}
  end
end
