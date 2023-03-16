defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Merging do
  @moduledoc """
  Mocks simple component combing two videos / frames / inputs into one.
  """

  alias Membrane.VideoCompositor.Scene.{Object, Resolution}

  @enforce_keys [:inputs, :resolution]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs: %{
            first: Object.name(),
            second: Object.name()
          },
          resolution: Resolution.t()
        }
end
