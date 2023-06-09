defmodule Membrane.VideoCompositor.Handler.InputsDescription do
  @moduledoc """
  Definition of all VC input videos used in composition.
  """

  alias Membrane.Pad
  alias Membrane.VideoCompositor.Handler.InputProperties

  @typedoc """
  Describe all VC input videos used in composition.
  """
  @type t :: %{Pad.ref_t() => InputProperties.t()}
end
