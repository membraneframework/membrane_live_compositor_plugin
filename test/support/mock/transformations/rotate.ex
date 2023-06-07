defmodule Membrane.VideoCompositor.Mock.Transformations.Rotate do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Transformation

  @enforce_keys [:degrees]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          degrees: non_neg_integer()
        }

  @impl true
  def encode(_rotate) do
    {0xDEADBEEF, 0xDEADBEEF}
  end

  @impl true
  def initialize(_wgpu_ctx) do
    {0xDEADBEEF, 0xDEADBEEF}
  end
end
