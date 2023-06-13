defmodule Membrane.VideoCompositor.Mock.Layouts.Merging do
  @moduledoc """
  Mocks simple component combing two videos / frames / inputs into one.
  """
  @behaviour Membrane.VideoCompositor.Object.Layout

  alias Membrane.VideoCompositor.{Object, Resolution}

  @enforce_keys [:inputs, :resolution]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs: %{
            first: Object.name(),
            second: Object.name()
          },
          resolution: Resolution.t()
        }

  @impl true
  def initialize(_wgpu_ctx) do
    {0xDEADBEEF, 0xDEADBEEF}
  end

  @impl true
  def encode(_merging) do
    {"merging", {0xDEADBEEF, 0xDEADBEEF}}
  end
end
