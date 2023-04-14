defmodule Membrane.VideoCompositor.Callbacks do
  @moduledoc false

  alias __MODULE__.Context
  alias Membrane.{Pad, StreamFormat, Time}
  alias Membrane.VideoCompositor.Scene

  @type state :: any()

  @type video_details :: {pad :: Pad.ref_t(), format :: StreamFormat.t()}

  @type callback_return :: {scene :: Scene.t(), state :: state()}

  @callback handle_init(ctx :: Context.Init.t()) :: callback_return()

  @callback handle_video_add(
              video :: video_details(),
              ctx :: Context.VideoAdd.t(),
              state :: state()
            ) :: callback_return()

  @callback handle_video_remove(
              video :: video_details(),
              ctx :: Context.VideoRemove.t(),
              state :: state()
            ) :: callback_return()

  @callback handle_info(msg :: any(), ctx :: Context.Info.t(), state :: state()) ::
              callback_return() | {start_ts :: Time.t(), callback_return()}
end

defmodule Membrane.VideoCompositor.Callbacks.Context do
  @moduledoc false
  alias Membrane.VideoCompositor.Scene

  @enforce_keys [:input_pads, :scenes_queue, :current_scene]
  defstruct @enforce_keys

  @type intput_pads :: list(Membrane.Pad.ref_t())

  @type start_scene_timestamp :: Membrane.Time.t()
  @type scenes_queue :: list({Scene.t(), start_scene_timestamp()})

  @type t :: %__MODULE__{
          input_pads: intput_pads(),
          scenes_queue: scenes_queue(),
          current_scene: Scene.t()
        }
end

defmodule Membrane.VideoCompositor.Callbacks.Context.Init do
  @moduledoc false
  alias Membrane.VideoCompositor.Callbacks.Context
  @type t :: Context.t()
end

defmodule Membrane.VideoCompositor.Callbacks.Context.VideoAdd do
  @moduledoc false
  alias Membrane.VideoCompositor.Callbacks.Context
  @type t :: Context.t()
end

defmodule Membrane.VideoCompositor.Callbacks.Context.VideoRemove do
  @moduledoc false
  alias Membrane.VideoCompositor.Callbacks.Context
  @type t :: Context.t()
end

defmodule Membrane.VideoCompositor.Callbacks.Context.Info do
  @moduledoc false

  alias Membrane.Time
  alias Membrane.VideoCompositor.Callbacks.Context

  @enforce_keys [:input_pads, :scenes_queue, :current_scene, :earliest_start]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          input_pads: Context.intput_pads(),
          scenes_queue: Context.scenes_queue(),
          current_scene: Scene.t(),
          earliest_start: Time.t()
        }
end
