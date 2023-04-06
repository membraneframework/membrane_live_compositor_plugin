defmodule Membrane.VideoCompositor.Mock.Transformations.Rotate do
  @moduledoc false

  @behaviour Membrane.VideoCompositor.Scene.Transformation

  @enforce_keys [:degrees]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          degrees: non_neg_integer()
        }

  @impl true
  def encode(_rotate) do
    2137
  end
end
