module Membrane.FFmpeg.VideoFilter.TextOverlay.Native

state_type "State"

spec create(
       text :: string,
       width :: int,
       height :: int,
       pixel_format_name :: atom,
       font_size :: int,
       font_color :: string,
       font_file :: string,
       box :: bool,
       box_color :: string,
       border_width :: int,
       border_color :: string,
       horizontal_align :: atom,
       vertical_align :: atom
     ) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec apply_filter(payload, state) :: {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, apply_filter: 2
