defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing handler allows to provide custom implementation and
  react to various events. In doing so, new scene and state can be set.
  """

  alias __MODULE__.CallbackCtx
  alias Membrane.{Pad, StreamFormat, Time}
  alias Membrane.VideoCompositor.Scene

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @type video_details :: {pad :: Pad.ref_t(), format :: StreamFormat.t()}

  @typedoc """
  Type of valid return from most of the callbacks.
  """
  @type callback_return :: {scene :: Scene.t(), state :: state()}

  @doc """
  Callback invoked uppon initialization of Video Compositor.
  """
  @callback handle_init(ctx :: CallbackCtx.Init.t()) :: callback_return()

  @doc """
  Callback invoked uppon addition of the new
  `Membrane.VideoCompositor.Scene.Object.InputVideo`
  """
  @callback handle_video_add(
              video :: video_details(),
              ctx :: CallbackCtx.VideoAdd.t(),
              state :: state()
            ) :: callback_return()

  @doc """
  Callback invoked uppon removal of
  `Membrane.VideoCompositor.Scene.Object.InputVideo`
  """
  @callback handle_video_remove(
              video :: video_details(),
              ctx :: CallbackCtx.VideoRemove.t(),
              state :: state()
            ) :: callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.
  """
  @callback handle_info(msg :: any(), ctx :: CallbackCtx.Info.t(), state :: state()) ::
              callback_return() | {start_ts :: Time.t(), callback_return()}
end
