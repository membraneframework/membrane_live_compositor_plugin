module Membrane.VideoCompositor.OpenGL.Native

state_type "State"

interface [CNode]

spec init(
  width :: int,
  height :: int
) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec join_frames(upper :: payload, lower :: payload, state) :: {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, init: 2
