module Membrane.VideoCompositor.Implementation.FFmpeg.Native

state_type "State"

type(
  raw_video :: %Membrane.VideoCompositor.Implementation.FFmpeg.Native.RawVideo{
    width: int,
    height: int,
    pixel_format: atom,
    framerate_num: int,
    framerate_den: int
  }
)

spec init(videos :: [raw_video]) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec apply_filter(payloads :: [payload], state) ::
       {:ok :: label, payload} | {:error :: label, reason :: atom}

spec duplicate_metadata(new_state :: state, old_state :: state) ::
       {:ok :: label, state} | {:error :: label, reason :: atom}

dirty :cpu, apply_filter: 3
