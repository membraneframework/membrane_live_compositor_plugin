defmodule Membrane.VideoCompositor.Handler.CallbackContext do
  @moduledoc """
  Structure representing a common part of the context
  for all of the callbacks.
  """
  alias Membrane.{Pad, Time}
  alias Membrane.VideoCompositor.Scene

  defmacro __using__(custom_fields_with_docs) do
    default_fields =
      quote do
        [
          input_pads: list(Pad.ref_t()),
          scenes_queue: list({start_scene_timestamp :: Time.t(), scene :: Scene.t()}),
          current_scene: Scene.t()
        ]
      end

    {custom_fields_docs, custom_fields} = Enum.unzip(custom_fields_with_docs)

    fields_docs =
      [
        """
        `:input_pads` - list of the input pads of a Video Compositor.

          This list will include pads as if event relevant to callback already happen,
          e.g. if event video is added during the event, `input_pads` will contain
          the new pad.
        """,
        """
        `:scenes_queue` - queued `Membrane.VideoCompositor.Scene` structs with
        timestamps specyfing when Video Compositor is supposed to start
        using specific scene to render.
        """,
        """
        `:current_scene` - most recent `Membrane.VideoCompositor.Scene` struct
        specyfing what is Video Compositor supposed to render at the moment.
        """
      ] ++ custom_fields_docs

    quote do
      @type t :: %__MODULE__{unquote_splicing(custom_fields ++ default_fields)}

      custom_fields_names = unquote(Keyword.keys(custom_fields))
      default_fields_names = unquote(Keyword.keys(default_fields))

      @enforce_keys custom_fields_names ++ default_fields_names
      defstruct @enforce_keys

      Membrane.VideoCompositor.Handler.DocsHelper.add_fields_docs(
        __MODULE__,
        unquote(fields_docs)
      )
    end
  end
end
