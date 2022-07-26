module Membrane.VideoCompositor.FFmpeg.Native

state_type "State"

spec init(
       width :: int,
       height :: int,
       pixel_format_name :: atom
     ) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec apply_filter(left_payload :: payload, right_payload :: payload, state) ::
       {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, apply_filter: 3
