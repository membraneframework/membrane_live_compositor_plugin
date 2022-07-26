module Membrane.VideoCompositor.FFmpeg.Native

state_type "State"

type(
  raw_video :: %Membrane.RawVideo{
    width: int,
    height: int,
    pixel_format: atom
  }
)

spec init(
       first_video :: raw_video,
       second_video :: raw_video
     ) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec apply_filter(left_payload :: payload, right_payload :: payload, state) ::
       {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, apply_filter: 3
