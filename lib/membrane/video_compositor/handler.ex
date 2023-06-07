defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and/or
  the inner custom state.
  """
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Handler.{CallbackContext, InputsDescription}

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediate, i.e. at the moment when the event happens.
  """
  @type callback_return :: {scene :: Scene.t(), state :: state()}

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
              inputs_description :: InputsDescription.t(),
              ctx :: CallbackContext.InputsChange.t(),
              state :: state()
            ) :: {scene :: Scene.t(), state :: state()}
end
