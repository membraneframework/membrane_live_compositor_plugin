defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and
  the inner custom state.
  """
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Handler.{CallbackContext, Inputs}

  @typedoc """
  Type of a valid return value from callback not changing the current scene.
  """
  @type idle_callback_return :: state()

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediate, i.e. at the moment when the event happens.
  """
  @type update_callback_return :: {scene :: Scene.t(), state :: state()}

  @typedoc """
  Type of a valid return value from callback allowing to pick start time of a new scene.
  """
  @type timed_update_callback_return ::
          {{scene :: Scene.t(), start_pts :: Membrane.Time.non_neg_t()}, state :: state()}

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediate, i.e. at the moment when the event happens.
  """
  @type callback_return :: update_callback_return()

  @doc """
  Callback invoked upon initialization of Video Compositor.
  """
  @callback handle_init(ctx :: CallbackContext.t()) :: idle_callback_return()

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
            ) :: idle_callback_return() | update_callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.

  This callback allow to communicate with a Video Compositor by
  sending custom messages and react to them. Therefore, it allows to
  react to custom events not specified by the other callbacks.
  """
  @callback handle_info(
              msg :: any(),
              ctx :: CallbackContext.t(),
              state :: state()
            ) :: idle_callback_return() | update_callback_return()
end
