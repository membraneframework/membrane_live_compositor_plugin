defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Overlay do
  @moduledoc """
  Mocks Overlay layout.

  Videos are places on output frame based on their
  given position.
  """

  alias Membrane.VideoCompositor.Examples.Mock.Layouts.Position
  alias Membrane.VideoCompositor.Object

  @enforce_keys [:overlay_spec, :inputs, :resolution]
  defstruct @enforce_keys

  @typedoc """
  A name used to identify placing of an objects.
  """
  @type placing_name :: atom()

  @typedoc """
  Specify how each input texture (received either from the input pad or rendered as
  an output of the previous object) maps on the rendered output of Overlay.
  """
  @type t :: %__MODULE__{
          overlay_spec: %{placing_name() => Position.t()},
          inputs: %{placing_name() => Object.name()},
          resolution: Object.object_output_resolution()
        }
end
