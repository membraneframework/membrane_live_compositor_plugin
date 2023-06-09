defmodule Membrane.VideoCompositor.TemporalScene do
  @moduledoc """
  This module contains types of Temporal Scene API.

  ## Expiration

  As opposed to a simple `t:Membrane.VideoCompositor.Scene.t/0`, this API allows
  you to define scenes or sequences of scenes that will expire after a finite time.
  In such cases, `c:Membrane.VideoCompositor.Handler.handle_scene_expire/2` callback will
  be called, allowing to specify the new scene.

  Types that are considered indefinite and will never expire:
  - `t:Membrane.VideoCompositor.Scene.t/0`
  - `t:repeat/0` with infinite number of `iterations`
  - `t:sequence/0` with one of above

  Please note that even indefinite types can be changed or ended by returning whole
  new scene specification in one of the `Membrane.VideoCompositor.Handler`.

  ## Examples

  ### Active Speaker

  Video Compositor is used in offline pipeline which is supposed to compose recording from
  videoconferencing tool. From the analysis of the audio files, active speaker can be determined.
  Active speaker is supposed the main one in the layout. Such scenes are called `x_scene`
  (as in x's video is the main one).

  In this specific scenario, after brief greeting with Alice and Bobby, Mikey talks for the
  entire meeting.

  This sequence will expire after 7 minutes and
  `c:Membrane.VideoCompositor.Handler.handle_scene_expire/2` will be called.
  ```
  sequence = [
    {:expiring, {alice_scene, Membrane.Time.seconds(32)}},
    {:expiring, {mikey_scene, Membrane.Time.seconds(51)}},
    {:expiring, {bobby_scene, Membrane.Time.seconds(48)}},
    {:expiring, {mikey_scene, Membrane.Time.seconds(21)}},
    {:expiring, {bobby_scene, Membrane.Time.seconds(37)}},
    {:expiring, {mikey_scene, Membrane.Time.seconds(231)}},
  ]
  ```

  ### Live stream viewers loop

  Video Compositor is used in live streaming pipeline. Viewers cameras should switch in loops (to show
  feedback from the audience), while main presenter camera should always be the most important one.
  Such scenes are called `x_scene` (as in x's video is shown in place for audience feed).

  This repeatition of sequence of scenes will never expire, af the number of iteration is infinite.
  ```
  {:repeat, {[{:expiring, :bobby_scene}, {:expiring, :alice_scene}], :inifinity}}
  ```

  ### Non reachable scenes

  In both of cases below Video Compositor will never render `mikey_scene`.
  `alice_scene` is indefinite, and so are the sequences.

  ```
    sequence = [
      alice_scene,
      {:expiring, {mikey_scene, Membrane.Time.seconds(51)}},
    ]
  ```

  ```
    alice_sequence = [
      {:expiring, {alice_scene, Membrane.Time.seconds(10)}}
    ]

    sequence = [
      {:repeat, {alice_sequence, :infinite}},
      {:expiring, {mikey_scene, Membrane.Time.seconds(23)}},
    ]
  ```
  """

  alias Membrane.VideoCompositor.Scene

  @typedoc """
  Type that defines all possible temporal scenes.
  """
  @type t() :: expiring() | repeat() | sequence()

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
  Defines a temporal `sequence` of scenes, that will be repeated the nubmer of times specified by `iterations`.

  If `iterations` are set to `:infinity`, this repeating sequence will never expire.
  """
  @type repeat :: {:repeat, {sequence :: sequence(), iterations :: pos_integer() | :infinity}}
end
