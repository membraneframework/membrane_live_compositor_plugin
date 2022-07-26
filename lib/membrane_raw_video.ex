defmodule Membrane.VideoCompositor.RawVideo do
  @typedoc """
  Raw video description, containing information about the width, height and pixel format.
  """

  defstruct width: 0, height: 0, pixel_format_name: :none

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          pixel_format_name: :atom
        }
end
