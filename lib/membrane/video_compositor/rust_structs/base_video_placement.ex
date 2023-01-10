defmodule Membrane.VideoCompositor.RustStructs.BaseVideoPlacement do
  @moduledoc """
  A struct describing the video position, size and z-value for use with the rust-based compositor on the output frame,
  before video transformations.
  ## Values
  - position: tuple given in pixels, relative to the top right corner of the output frame,
  represents the position on the output frame before transformations
  - size: tuple given in pixels, represents video resolution on the output frame before transformations
  - z_value: float in [0.0, 1.0] range, specifies priority: videos with higher `z_value`s are 'in front' of
  videos with lower `z_value`s
  ## Examples
  If you want to place the video in the bottom left quarter of the 4k output frame,
  above videos on 0.0 z_value level:

        iex> alias Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
        Membrane.VideoCompositor.RustStructs.BaseVideoPlacement
        iex> %BaseVideoPlacement{ position: {1920, 1080}, size: {1920, 1080}, z_value: 0.5}
        %Membrane.VideoCompositor.RustStructs.BaseVideoPlacement{
          position: {1920, 1080},
          size: {1920, 1080},
          z_value: 0.5
        }
  """

  @type t :: %__MODULE__{
          position: {integer(), integer()},
          size: {non_neg_integer(), non_neg_integer()},
          z_value: float()
        }

  @enforce_keys [:position, :size]
  defstruct [:position, :size, z_value: 0.0]
end
