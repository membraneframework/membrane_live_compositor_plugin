module Membrane.VideoCompositor.OpenGL.Native

state_type "State"

interface [NIF]

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

spec join_frames(upper :: payload, lower :: payload, state) ::
       {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, init: 2
dirty :cpu, join_frames: 3
