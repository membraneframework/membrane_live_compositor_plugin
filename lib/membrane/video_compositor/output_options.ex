defmodule Membrane.LiveCompositor.OutputOptions do
  @moduledoc """
  Options of LiveCompositor output.
  """

  @typedoc """
  After rendering LiveCompositors outputs are encoded.
  Changing encoder preset can substantially impact output quality as well as CPU usage.
  See [FFmpeg docs](https://trac.ffmpeg.org/wiki/Encode/H.264#Preset) to learn more.
  """
  @type encoder_preset ::
          :ultrafast
          | :superfast
          | :veryfast
          | :faster
          | :fast
          | :medium
          | :slow
          | :slower
          | :veryslow
          | :placebo

  @enforce_keys [:width, :height, :id]
  defstruct @enforce_keys ++ [encoder_preset: :fast]

  @typedoc """
  Options of LiveCompositor output.
  """
  @type t :: %__MODULE__{
          width: Membrane.RawVideo.width_t(),
          height: Membrane.RawVideo.height_t(),
          id: Membrane.LiveCompositor.output_id(),
          encoder_preset: encoder_preset()
        }
end
