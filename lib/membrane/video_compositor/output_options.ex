defmodule Membrane.LiveCompositor.OutputOptions do
  @moduledoc """
  Options of LiveCompositor output.
  """

  @enforce_keys [:id, :video]
  defstruct @enforce_keys ++ [port: nil]

  @typedoc """
  Options of LiveCompositor output.
  """
  @type t :: %__MODULE__{
          id: Membrane.LiveCompositor.output_id(),
          port: :inet.port_number() | Membrane.LiveCompositor.port_range() | nil,
          video: __MODULE__.Video.t()
        }

  defmodule Video do
    @moduledoc """
    Video options of LiveCompositor output.
    """
    @enforce_keys [:width, :height, :initial]
    defstruct @enforce_keys ++ [encoder_preset: :fast]

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

    @typedoc """
    Options of LiveCompositor output.
    """
    @type t :: %__MODULE__{
            width: Membrane.RawVideo.width_t(),
            height: Membrane.RawVideo.height_t(),
            encoder_preset: encoder_preset(),
            initial: any()
          }
  end
end
