defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and
  the inner custom state.
  """
  alias Membrane.Pad
  alias Membrane.VideoCompositor
  alias Membrane.VideoCompositor.Handler.InputProperties
  alias Membrane.VideoCompositor.Scene

  @typedoc """
  Module implementing `#{inspect(__MODULE__)}` behaviour.
  """
  @type t :: module()

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @typedoc """
  Contains state of VC before handling event invoking callback.
  """
  @type context :: %{
          scene: Scene.t(),
          inputs: inputs(),
          next_frame_pts: Membrane.Time.non_neg(),
          scenes_queue: [{start_pts :: Membrane.Time.non_neg(), new_scene :: Scene.t()}]
        }

  @typedoc """
  Describe all VC input videos used in composition.
  """
  @type inputs() :: %{Pad.ref() => InputProperties.t()}

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediate, i.e. at the moment when the event happens.
  """
  @type immediate_callback_return :: {scene :: Scene.t(), state :: state()}

  @typedoc """
  Type of a valid return value from callback allowing to pick start time of a new scene.
  """
  @type timed_callback_return ::
          {{scene :: Scene.t(), start_pts :: Membrane.Time.non_neg()}, state :: state()}

  @doc """
  Callback invoked upon initialization of Video Compositor.
  """
  @callback handle_init(init_options :: VideoCompositor.init_options()) :: state()

  @doc """
  Callback invoked upon change of VC `t:inputs()`.

  `inputs` changing input videos:
  - video added
  - video removed
  - video stream format change
  """
  @callback handle_inputs_change(
              inputs :: inputs(),
              ctx :: context(),
              state :: state()
            ) :: immediate_callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.

  This callback allows one to communicate with a Video Compositor by
  sending custom messages and reacting to them.
  """
  @callback handle_info(
              msg :: any(),
              ctx :: context(),
              state :: state()
            ) :: immediate_callback_return() | timed_callback_return()
end
