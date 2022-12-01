defmodule Membrane.VideoCompositor.RustStructs.VideoLayout do
  @moduledoc """
  A struct describing the video position, size in the output frame and z-value for use with the rust-based compositor.
  Position is relative to the top right corner of the viewport, given in pixels.
  The `z_value` specifies priority: videos with higher `z_value`s are 'in front' of videos with lower `z_value`s.
  `z_value` has to be between 0.0 and 1.0.
  """

  @type t :: %__MODULE__{
          position: {non_neg_integer(), non_neg_integer()},
          display_size: {non_neg_integer(), non_neg_integer()},
          z_value: float()
        }

  @enforce_keys [:position, :display_size]
  defstruct [:position, :display_size, z_value: 0.0]
end
