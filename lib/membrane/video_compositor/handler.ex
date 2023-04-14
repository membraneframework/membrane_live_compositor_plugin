defmodule Membrane.VideoCompositor.Handler do
  @moduledoc false

  alias __MODULE__.CallbackCtx
  alias Membrane.{Pad, StreamFormat, Time}
  alias Membrane.VideoCompositor.Scene

  @type state :: any()

  @type video_details :: {pad :: Pad.ref_t(), format :: StreamFormat.t()}

  @type callback_return :: {scene :: Scene.t(), state :: state()}

  @callback handle_init(ctx :: CallbackCtx.Init.t()) :: callback_return()

  @callback handle_video_add(
              video :: video_details(),
              ctx :: CallbackCtx.VideoAdd.t(),
              state :: state()
            ) :: callback_return()

  @callback handle_video_remove(
              video :: video_details(),
              ctx :: CallbackCtx.VideoRemove.t(),
              state :: state()
            ) :: callback_return()

  @callback handle_info(msg :: any(), ctx :: CallbackCtx.Info.t(), state :: state()) ::
              callback_return() | {start_ts :: Time.t(), callback_return()}
end
