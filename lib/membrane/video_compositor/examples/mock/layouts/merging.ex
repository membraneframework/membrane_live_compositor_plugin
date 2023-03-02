defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Merging do
  @moduledoc """
  Mocks simple component combing two videos / frames / inputs into one.
  """

  alias Membrane.VideoCompositor.Scene.{Layout, Object, Resolution}

  @enforce_keys Layout.get_layout_enforce_keys()
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          inputs: %{
            first: Object.name_t(),
            second: Object.name_t()
          },
          resolution: Resolution.t()
        }
end
