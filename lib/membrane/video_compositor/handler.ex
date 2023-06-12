defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing a handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and/or
  the inner custom state.
  """

  alias __MODULE__.{CallbackContext, Inputs}
  alias Membrane.{Pad, StreamFormat, Time}
  alias Membrane.VideoCompositor.{Scene, TemporalScene}

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @type video_details :: {pad :: Pad.ref_t(), format :: StreamFormat.t()}

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediately, i.e. at the moment when the event happens.
  """
  @type immediate_callback_return ::
          {scene :: Scene.t() | TemporalScene.t(), state :: state()}

  @typedoc """
  Type of a valid return value from callback allowing to pick the start time of a new scene.
  The `state` will be changed immediately.
  """
  @type timed_callback_return ::
          {{start_ts :: Time.t(), scene :: Scene.t() | TemporalScene.t()}, state :: state()}

  @doc """
  Callback invoked upon initialization of Video Compositor.
  """
  @callback handle_init(ctx :: CallbackContext.Init.t()) :: state()

  @doc """
  Callback invoked upon change of VC input videos.

  Events changing input videos:
  - video added
  - video removed
  - video stream format change
  """
  @callback handle_inputs_change(
              inputs :: Inputs.t(),
              ctx :: CallbackContext.t(),
              state :: state()
            ) :: immediate_callback_return() | timed_callback_return()

  @doc """
  Callback invoked upon expiration of Temporal Scene.

  See `Membrane.VideoCompositor.TemporalScene`.
  """
  @callback handle_scene_expire(
              expired_scene :: TemporalScene.t(),
              ctx :: CallbackContext.t(),
              state :: state()
            ) :: immediate_callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.

  This callback allows one to communicate with a Video Compositor by
  sending custom messages and reacting to them.
  """
  @callback handle_info(msg :: any(), ctx :: CallbackContext.t(), state :: state()) ::
              immediate_callback_return() | timed_callback_return()
end
