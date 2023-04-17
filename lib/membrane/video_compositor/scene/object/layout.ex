defmodule Membrane.VideoCompositor.Scene.Object.Layout do
  @moduledoc """
  Structure representing Layout objects.

  Layouts can take multiple renderable objects as input and combine
  them into one frame. Fadings, Grids, Overlays, Transitions, etc.
  can be defined as Layouts.

  Basically it's a multi-input, single-output node in processing graph.
  """
  alias Membrane.VideoCompositor.Scene.{Object, Resolution}

  @typedoc """
  A layout-internal identifier, which the layout can use to determine
  the way of rendering specific input objects. See `t:inputs/0` for more info.
  """
  @type internal_name :: Object.name()

  @typedoc """
  A map defining how to map internal layout's identifiers to scene objects.

  ## Examples
  a simple layout could have an `inputs` map that looks like this:
  ```elixir
  %{
    background: :video1,
    main_presenter: :video2,
    side_presenter: :video3,
  }
  ```

  Keep in mind that this maps __internal names__ => __scene object names__
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

  defmodule RustlerFriendly do
    @moduledoc false
    # A rustler-friendly version of the Layout, prepared for rust serialization
    alias Membrane.VideoCompositor.Scene.Object.RustlerFriendly, as: RFObject
    alias Membrane.VideoCompositor.Scene.Resolution

    @typedoc """
    A rustler-friendly version of the internal name
    """
    @type internal_name :: RFObject.name()

    @typedoc """
    A rustler-friendly version of the inputs map. Keep in mind that this maps
    __internal names__ => __scene object names__.
    """
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

  @doc """
  A callback used for encoding the static layout data into a rust-based representation.
  This should be implemented in user-defined layouts. This function is responsible for encoding
  the optional fields and all other parts of the layout into the user-defined rust struct.
  We don't know yet how exactly this system is going to work, so this is just a placeholder
  for now.
  """
  @callback encode(t()) :: RustlerFriendly.rust_representation()

  @doc false
  # Encode the layout to a Layout.RustlerFriendly in order to prepare it for
  # the rust conversion.
  @spec encode(t()) :: RustlerFriendly.t()
  def encode(layout = %module{inputs: inputs, resolution: resolution}) do
    rust_representation = module.encode(layout)

    encoded_resolution = Object.encode_output_resolution(resolution)

    encoded_inputs =
      inputs
      |> Map.new(fn {internal_name, object_name} ->
        {encode_internal_name(internal_name), Object.encode_name(object_name)}
      end)

    %RustlerFriendly{
      inputs: encoded_inputs,
      resolution: encoded_resolution,
      implementation: rust_representation
    }
  end

  @spec encode_internal_name(internal_name()) :: RustlerFriendly.internal_name()
  defp encode_internal_name(name) do
    Object.encode_name(name)
  end
end
