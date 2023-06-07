defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and/or
  the inner custom state.
  """

  alias __MODULE__.CallbackContext
  alias Membrane.{Pad, StreamFormat, Time}
  alias Membrane.VideoCompositor.Scene

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @type video_details :: {pad :: Pad.ref_t(), format :: StreamFormat.t()}

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediate, i.e. at the moment when the event happens.
  """
  @type immediate_callback_return ::
          {scene :: Scene.t() | Scene.Temporal.indefinite(), state :: state()}

  @typedoc """
  Type of a valid return value from callback allowing to pick start time of a new scene.
  """
  @type timed_callback_return ::
          {{start_ts :: Time.t(), scene :: Scene.t() | Scene.Temporal.indefinite()},
           state :: state()}

  @typedoc """
  Type of a valid return value from callback not changing the current scene.
  """
  @type idle_callback_return :: {state :: state()}

  @doc """
  Callback invoked upon initialization of Video Compositor.
  """
  @callback handle_init() :: immediate_callback_return()

  @doc """
  Callback invoked upon addition of the new
  `Membrane.VideoCompositor.Scene.Object.InputVideo`
  """
  @callback handle_video_add(
              video :: video_details(),
              ctx :: CallbackContext.VideoAdd.t(),
              state :: state()
            ) :: immediate_callback_return() | idle_callback_return()

  @doc """
  Callback invoked upon removal of
  `Membrane.VideoCompositor.Scene.Object.InputVideo`
  """
  @callback handle_video_remove(
              video :: video_details(),
              ctx :: CallbackContext.VideoRemove.t(),
              state :: state()
            ) :: immediate_callback_return() | idle_callback_return()

  @doc """
  Callback invoked upon expiration of Temporal Scene.

  See `Membrane.VideoCompositor.Scene.Temporal`.
  """
  @callback handle_scene_expire(
              ctx :: CallbackContext.SceneExpire.t(),
              state :: state()
            ) :: immediate_callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.

  This callback allow to communicate with a Video Compositor by
  sending custom messages and react to them. Therefore, it allows to
  react to custom events not specified by the other callbacks.

  Please be minded that this callback does not have fixed start
  and you can specify start by returning `t:timed_callback_return/0`.
  The earliest start is specified in `:earliest_start` field of
  `Membrane.VideoCompositor.Handler.CallbackContext.Info`.
  """
  @callback handle_info(msg :: any(), ctx :: CallbackContext.Info.t(), state :: state()) ::
              immediate_callback_return()
              | timed_callback_return()
              | idle_callback_return()
end
