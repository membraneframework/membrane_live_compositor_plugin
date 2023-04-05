defmodule Membrane.VideoCompositor.Scene.Object.Layout do
  @moduledoc """
  Structure representing Layout objects.

  Layouts can take multiple renderable objects as input and combine
  them into one frame. Fadings, Grids, Overlays, Transitions, etc.
  can be defined as Layouts.

  Basically it's a multi-input, single-output node in processing graph.
  """
  alias Membrane.VideoCompositor.Scene.{Object, Resolution}

  defmodule RustlerFriendly do
    @moduledoc false
    alias Membrane.VideoCompositor.Scene.Object.RustlerFriendly, as: RFObject
    alias Membrane.VideoCompositor.Scene.Resolution

    @type internal_name :: RFObject.name()

    @type inputs :: %{internal_name() => RFObject.name()}
    @type output_resolution :: {:resolution, Resolution.t()} | {:name, Object.name()}

    # in a more 'final' product this should be some kind of a layout identifier.
    # I thought of making this a UUID that would correspond to an implementation
    # on the rust side, but layout names would work fine too.
    @type rust_representation :: integer()

    @type t :: %__MODULE__{
            :inputs => inputs(),
            :resolution => output_resolution(),
            # unsure about calling this `implementation`.
            :implementation => rust_representation()
          }

    @enforce_keys [:inputs, :resolution, :implementation]
    defstruct @enforce_keys
  end

  @type internal_name :: Object.name()

  @typedoc """
  Type of a map defining on how to map internal layout's ids
  to Scene objects
  """
  @type inputs :: %{internal_name() => Object.name()}

  @typedoc """
  Defines how the output resolution of a layout texture can be specified.

  Texture resolution can be specified as:
  - plain `Membrane.VideoCompositor.Resolution.t()`
  - resolution of another object
  """
  @type output_resolution :: Resolution.t() | Object.name()

  @typedoc """
  Specify that Layouts:
    - should be defined as structs
    - should have :inputs and :resolution fields
    - can have custom fields
  """
  @type t :: %{
          :__struct__ => module(),
          :inputs => inputs(),
          :resolution => output_resolution(),
          optional(any()) => any()
        }

  @type rust_representation :: non_neg_integer()

  @callback encode(t()) :: rust_representation()

  @spec encode(t()) :: RustlerFriendly.t()
  def encode(layout = %module{inputs: inputs, resolution: resolution}) do
    rust_representation = module.encode(layout)

    encoded_resolution = Object.encode_output_resolution(resolution)

    encoded_inputs =
      inputs
      |> Map.new(fn {k, v} -> {Object.encode_name(k), Object.encode_name(v)} end)

    %RustlerFriendly{
      inputs: encoded_inputs,
      resolution: encoded_resolution,
      implementation: rust_representation
    }
  end
end
