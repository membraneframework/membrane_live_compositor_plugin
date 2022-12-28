defmodule Membrane.VideoCompositor.RustStructs.VideoPlacement do
  @moduledoc """
  A struct describing the video position, size and z-value for use with the rust-based compositor on the output frame,
  before video transformations.
  ## Values
  - base_position: tuple given in pixels, relative to the top top right corner of the output frame,
  represents position on output frame before transformations
  - base_size: tuple given in pixels, represents video resolution on the output frame before transformations
  - z_value: float in [0.0, 1.0] range, specifies priority: videos with higher `z_value`s are 'in front' of
  videos with lower `z_value`s
  ## Examples
  If you want to place video in bottom left quarter of 4k output frame, above videos on 0.0 base_z_value level:

        iex> alias Membrane.VideoCompositor.RustStructs.VideoPlacement
        Membrane.VideoCompositor.RustStructs.VideoPlacement
        iex> %VideoPlacement{ base_position: {1920, 1080}, base_size: {1920, 1080}, base_z_value: 0.5}
        %Membrane.VideoCompositor.RustStructs.VideoPlacement{
          base_position: {1920, 1080},
          base_size: {1920, 1080},
          base_z_value: 0.5
        }
  """

  @type t :: %__MODULE__{
          base_position: {non_neg_integer(), non_neg_integer()},
          base_size: {non_neg_integer(), non_neg_integer()},
          base_z_value: float()
        }

  @enforce_keys [:base_position, :base_size]
  defstruct [:base_position, :base_size, base_z_value: 0.0]
end
