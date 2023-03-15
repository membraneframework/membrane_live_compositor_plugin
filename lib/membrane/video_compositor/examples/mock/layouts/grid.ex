defmodule Membrane.VideoCompositor.Examples.Mock.Layouts.Grid do
  @moduledoc """
  Mock Grid Layout.

  Videos placements are defined by the :video_count
  parameter. Mocks some components defining different
  video arrangements for a different number of input sources.
  """
  @behaviour Membrane.VideoCompositor.Scene.Object.Layout

  alias Membrane.VideoCompositor.Scene.{Object, Resolution}

  @enforce_keys [:videos_count, :inputs, :resolution]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          videos_count: non_neg_integer(),
          inputs: %{
            integer() => Object.name()
          },
          resolution: Resolution.t()
        }

  @impl true
  def encode(_grid) do
    make_ref()
  end
end
