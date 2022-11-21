defmodule Membrane.VideoCompositor.RustStructs.VideoProperties do
  @moduledoc """
  A properties struct describing the video position, scale and z-value for use with the rust-based compositor.
  Position relative to the top right corner of the viewport, in pixels.
  The `z` value specifies priority: a lower `z` is 'in front' of higher `z` values.
  """

  @type t :: %__MODULE__{
          x: non_neg_integer(),
          y: non_neg_integer(),
          z: float(),
          scale: float()
        }

  @enforce_keys [:x, :y, :z, :scale]
  defstruct @enforce_keys

  @spec from_tuple({non_neg_integer(), non_neg_integer(), float(), float()}) :: t()
  def from_tuple({_x, _y, z, _scale}) when z < 0.0 or z > 1.0 do
    raise "z = #{z} is out of the (0.0, 1.0) range"
  end

  def from_tuple({x, y, z, scale}) do
    %__MODULE__{x: x, y: y, z: z, scale: scale}
  end
end
