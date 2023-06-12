defmodule Membrane.VideoCompositor.Handler do
  @moduledoc """
  Module defining behaviour of handlers.

  Implementing a handler allows to provide custom implementation and
  react to various events, among others by setting a new scene and/or
  the inner custom state.

  For more explanation on scene see: `Membrane.VideoCompositor.Scene`

  ## Examples

  ### Simple video conference room
  Video Compositor is used in video conference app like the [Membrane Videoroom](https://github.com/membraneframework/membrane_videoroom).
  Composition is determined by number of users.

  This is how handler module might look like (assuming user implemented SceneMaker.get_scene(users_count)):
  ```
  defmodule ConferenceHandler do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Handler

    alias Membrane.VideoCompositor.Scene

    @impl true
    def handle_init(_init_options) do
      %{user_count_to_scene: get_users_scene_mapping()}
    end

    @impl true
    def handle_inputs_change(inputs, _ctx, state) do
      {Map.get(state.user_count_to_scene, map_size(inputs), default_scene()), state}
    end

    @spec get_users_scene_mapping() :: %{(users_count :: non_neg_integer()) => Scene.t()}
    defp get_users_scene_mapping() do
      Map.new(0..10, fn users_count -> {users_count, SceneMaker.get_scene(users_count)} end)
    end

    @spec default_scene() :: Scene.t()
    defp default_scene() do
      %Scene{
        objects: default_objects,
        output: default_output
      }
    end
  end

  ```
  """

  alias __MODULE__.InputProperties
  alias Membrane.{Pad, VideoCompositor}
  alias Membrane.VideoCompositor.Scene

  @typedoc """
  Type of user-managed inner state of the handler.
  """
  @type state :: any()

  @typedoc """
  Contains state of VC before handling event invoking callback.
  """
  @type context :: %{
          scene: Scene.t() | temporal_scene(),
          inputs: inputs(),
          next_frame_pts: Membrane.Time.non_neg_t()
        }

  @typedoc """
  Type that defines all possible temporal scenes.

  ## Expiration

  As opposed to a simple `t:Membrane.VideoCompositor.Scene.t/0`, this API allows
  you to define scenes or sequences of scenes that will expire after a finite time.
  In such cases, `c:handle_scene_expire/3` callback will
  be called, allowing to specify the new scene.

  Types that are considered indefinite and will never expire:
  - `t:Membrane.VideoCompositor.Scene.t/0`
  - `t:repeat/0` with an infinite number of `iterations`
  - `t:sequence/0` with one of above

  Please note that even indefinite types can be changed or ended by returning whole
  new scene specification in one of the `Membrane.VideoCompositor.Handler`.

  ## Examples

  ### Active Speaker

  Video Compositor is used in the offline pipeline which is supposed to compose recording from the
  videoconferencing tool. From the analysis of the audio files, the active speaker can be determined.
  The active speaker is supposed the main one in the layout. Such scenes are called `x_scene`
  (as in x's video is the main one).

  In this specific scenario, after a brief greeting with Alice and Bobby, Mikey talks for the
  entire meeting.

  This sequence will expire after 7 minutes and
  `c:handle_scene_expire/3` will be called.
  ```
  sequence = [
    {:expiring, {alice_scene, Membrane.Time.seconds(32)}},
    {:expiring, {mikey_scene, Membrane.Time.seconds(51)}},
    {:expiring, {bobby_scene, Membrane.Time.seconds(48)}},
    {:expiring, {mikey_scene, Membrane.Time.seconds(21)}},
    {:expiring, {bobby_scene, Membrane.Time.seconds(37)}},
    {:expiring, {mikey_scene, Membrane.Time.seconds(231)}}
  ]
  ```

  ### Live stream viewers loop

  Video Compositor is used in the live streaming pipeline. Viewer's cameras should switch in loops (to show
  feedback from the audience), while the main presenter's camera should always be the most important one.
  Such scenes are called `x_scene` (as in x's video is shown in place for audience feed).

  This repetition of the sequence of scenes will never expire, as the number of iterations is infinite.
  ```
  {:repeat, {[{:expiring, :bobby_scene}, {:expiring, :alice_scene}], :infinity}}
  ```

  ### Non-reachable scenes

  In both of the cases below Video Compositor will never render `mikey_scene`.
  `alice_scene` is indefinite, and so are the sequences.

  ```
    sequence = [
      alice_scene,
      {:expiring, {mikey_scene, Membrane.Time.seconds(51)}}
    ]
  ```

  ```
    alice_sequence = [
      {:expiring, {alice_scene, Membrane.Time.seconds(10)}}
    ]

    sequence = [
      {:repeat, {alice_sequence, :infinite}},
      {:expiring, {mikey_scene, Membrane.Time.seconds(23)}}
    ]
  ```
  """
  @type temporal_scene :: expiring() | repeat() | sequence()

  @typedoc """
  Defines a `sequence` of scenes, including expiring ones.

  Please note that if the element of a sequence is `t:Membrane.VideoCompositor.Scene.t/0`
  or `t:repeat/0` with an infinite number of `iterations`:
    - it will be used indefinitely
    - this sequence will never expire
  """
  @type sequence :: [expiring() | repeat() | Scene.t()]

  @typedoc """
  Defines a temporal `scene` that is supposed to expire after the specified `duration`.
  """
  @type expiring :: {:expiring, {scene :: Scene.t(), duration :: Membrane.Time.non_neg_t()}}

  @typedoc """
  Defines a temporal `sequence` of scenes, that will be repeated the number of times specified by `iterations`.

  If `iterations` are set to `:infinity`, this repeating sequence will never expire.
  """
  @type repeat :: {:repeat, {sequence :: sequence(), iterations :: pos_integer() | :infinity}}

  @typedoc """
  Type of a valid return value from the callback. By returning this type,
  the scene will be changed immediately, i.e. at the moment when the event happens.
  """
  @type callback_return :: {scene :: Scene.t() | temporal_scene(), state :: state()}

  @typedoc """
  Describe all VC input videos used in composition.
  """
  @type inputs :: %{Pad.ref_t() => InputProperties.t()}

  @doc """
  Callback invoked upon initialization of Video Compositor.
  """
  @callback handle_init(init_options :: VideoCompositor.init_options()) :: state()

  @doc """
  Callback invoked upon change of VC `inputs`.

  `inputs` changing events:
  - video added
  - video removed
  - video stream format change
  """
  @callback handle_inputs_change(
              inputs :: inputs(),
              ctx :: context(),
              state :: state()
            ) :: callback_return()

  @doc """
  Callback invoked upon expiration of `temporal scene`.

  See `t:temporal_scene()`.
  """
  @callback handle_scene_expire(
              expired_scene :: temporal_scene(),
              ctx :: context(),
              state :: state()
            ) :: callback_return()

  @doc """
  Callback invoked when video compositor receives a message
  that is not recognized as an internal membrane message.

  This callback allows one to communicate with a Video Compositor by
  sending custom messages and reacting to them.
  """
  @callback handle_info(msg :: any(), ctx :: context(), state :: state()) ::
              callback_return()
end
