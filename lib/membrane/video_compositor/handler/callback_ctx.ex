defmodule Membrane.VideoCompositor.Handler.CallbackCtx do
  @moduledoc """
  Structure representing a common part of the context
  for all of the callbacks.
  """
  alias Membrane.{Pad, Time}
  alias Membrane.VideoCompositor.Scene

  defmacro __using__(fields) do
    default_fields =
      quote do
        [
          input_pads: list(Pad.ref_t()),
          scenes_queue: list({scene :: Scene.t(), start_scene_timestamp :: Time.t()}),
          current_scene: Scene.t()
        ]
      end

    quote do
      @type t :: %__MODULE__{unquote_splicing(fields ++ default_fields)}

      fields_names = unquote(Keyword.keys(fields))
      default_fields_names = unquote(Keyword.keys(default_fields))

      @enforce_keys Module.get_attribute(__MODULE__, :enforce_keys, fields_names) ++
                      default_fields_names

      defstruct fields_names ++ default_fields_names
    end
  end
end
