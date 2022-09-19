defmodule Membrane.VideoCompositor.Scene.Video do
  @moduledoc """
  Video contains video state.
  """

  @type t :: %__MODULE__{
          position: %Membrane.VideoCompositor.Position{}
        }
  @enforce_keys [:position]
  defstruct position: nil
end
