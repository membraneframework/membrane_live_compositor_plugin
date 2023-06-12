defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing a handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and/or
  the inner custom state.
  """

  alias __MODULE__.{CallbackContext, InputProperties}
  alias Membrane.{Pad, StreamFormat}
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
  @type callback_return :: {scene :: Scene.t() | TemporalScene.t(), state :: state()}

  @typedoc """
  Describe all VC input videos used in composition.
  """
  @type inputs :: %{Pad.ref_t() => InputProperties.t()}

  @doc """
  Callback invoked upon initialization of Video Compositor.
  """
  @callback handle_init(ctx :: CallbackContext.Init.t()) :: state()

  @doc """
  Callback invoked upon change of VC input videos.

  `input` changing events:
  - video added
  - video removed
  - video stream format change
  """
  @callback handle_input_change(
              input :: inputs(),
              ctx :: CallbackContext.t(),
              state :: state()
            ) :: callback_return()

  @doc """
  Callback invoked upon expiration of Temporal Scene.

  See `Membrane.VideoCompositor.TemporalScene`.
  """
  @callback handle_scene_expire(
              expired_scene :: TemporalScene.t(),
              ctx :: CallbackContext.t(),
              state :: state()
            ) :: callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.

  This callback allows one to communicate with a Video Compositor by
  sending custom messages and reacting to them.
  """
  @callback handle_info(msg :: any(), ctx :: CallbackContext.t(), state :: state()) ::
              callback_return()
end
