defmodule Membrane.LiveCompositor.Action do
  @moduledoc false

  alias Membrane.LiveCompositor.ApiClient

  defmodule RegisterImage do
    @moduledoc """
    Action to register an image.
    """

    @typedoc """
    Image type
    """
    @type image_type :: :png | :jpeg | :gif | :svg

    @enforce_keys [:image_id, :asset_type]
    defstruct @enforce_keys ++ [url: nil, path: nil, resolution: nil]

    @typedoc """
    - Fields `url` and `path` are mutually exclusive. Exactly one of them should be set at the time.
    - Field `resolution` is only supported when `:asset_type` is set to `:svg`.
    """
    @type t :: %__MODULE__{
            image_id: String.t(),
            asset_type: image_type(),
            url: String.t() | nil,
            path: String.t() | nil,
            resolution: %{width: non_neg_integer(), height: non_neg_integer()} | nil
          }
  end

  defimpl ApiClient.IntoRequest, for: RegisterImage do
    @spec into_request(RegisterImage.t()) :: ApiClient.request()
    def into_request(action) do
      body = %{
        asset_type: action.asset_type,
        path: action.path,
        url: action.url,
        resolution: action.resolution
      }

      encoded_id = URI.encode_www_form(action.image_id)
      {:post, "/api/image/#{encoded_id}/register", body}
    end
  end

  defmodule RegisterShader do
    @moduledoc """
    Action to register a shader instance.
    """

    @enforce_keys [:shader_id, :source]
    defstruct @enforce_keys ++ []

    @typedoc """
    WGSL shader source code. [Learn more](https://compositor.live/docs/concept/shaders).
    """
    @type shader_source :: String.t()

    @type t :: %__MODULE__{
            shader_id: String.t(),
            source: shader_source()
          }
  end

  defimpl ApiClient.IntoRequest, for: RegisterShader do
    @spec into_request(RegisterShader.t()) :: ApiClient.request()
    def into_request(action) do
      body = %{
        source: action.source
      }

      encoded_id = URI.encode_www_form(action.shader_id)
      {:post, "/api/shader/#{encoded_id}/register", body}
    end
  end

  defmodule UnregisterImage do
    @moduledoc """
    Action to unregister an image.
    """

    @enforce_keys [:image_id]
    defstruct @enforce_keys ++ []

    @type t :: %__MODULE__{
            image_id: String.t()
          }
  end

  defimpl ApiClient.IntoRequest, for: UnregisterImage do
    @spec into_request(UnregisterImage.t()) :: ApiClient.request()
    def into_request(action) do
      encoded_id = URI.encode_www_form(action.image_id)
      {:post, "/api/image/#{encoded_id}/unregister", %{}}
    end
  end

  defmodule UnregisterShader do
    @moduledoc """
    Action to unregister a shader instance.
    """

    @enforce_keys [:shader_id]
    defstruct @enforce_keys ++ []

    @type t :: %__MODULE__{
            shader_id: String.t()
          }
  end

  defimpl ApiClient.IntoRequest, for: UnregisterShader do
    @spec into_request(UnregisterShader.t()) :: ApiClient.request()
    def into_request(action) do
      encoded_id = URI.encode_www_form(action.shader_id)
      {:post, "/api/shader/#{encoded_id}/unregister", %{}}
    end
  end

  defmodule UnregisterInput do
    @moduledoc """
    Action to unregister an input stream. Unregister will happen automatically when you unlink the
    pads.
    """

    alias Membrane.LiveCompositor

    @enforce_keys [:input_id]
    defstruct @enforce_keys ++ [schedule_time: nil]

    @type t :: %__MODULE__{
            input_id: LiveCompositor.input_id(),
            schedule_time: Membrane.Time | nil
          }
  end

  defimpl ApiClient.IntoRequest, for: UnregisterInput do
    @spec into_request(UnregisterInput.t()) :: ApiClient.request()
    def into_request(action) do
      body = %{
        schedule_time_ms:
          case action.schedule_time do
            nil -> nil
            offset -> Membrane.Time.as_milliseconds(offset, :round)
          end
      }

      encoded_id = URI.encode_www_form(action.input_id)
      {:post, "/api/input/#{encoded_id}/unregister", body}
    end
  end

  defmodule UnregisterOutput do
    @moduledoc """
    Action to unregister an output stream. Unregister will happen automatically when you unlink the
    pads.
    """

    alias Membrane.LiveCompositor

    @enforce_keys [:output_id]
    defstruct @enforce_keys ++ [schedule_time: nil]

    @type t :: %__MODULE__{
            output_id: LiveCompositor.output_id(),
            schedule_time: Membrane.Time | nil
          }
  end

  defimpl ApiClient.IntoRequest, for: UnregisterOutput do
    @spec into_request(UnregisterOutput.t()) :: ApiClient.request()
    def into_request(action) do
      body = %{
        schedule_time_ms:
          case action.schedule_time do
            nil -> nil
            offset -> Membrane.Time.as_milliseconds(offset, :round)
          end
      }

      encoded_id = URI.encode_www_form(action.output_id)
      {:post, "/api/output/#{encoded_id}/unregister", body}
    end
  end

  defmodule UpdateVideoOutput do
    @moduledoc """
    Action to update the scene definition that describes what should be rendered on a specified output.
    """

    alias Membrane.LiveCompositor

    @enforce_keys [:output_id, :root]
    defstruct @enforce_keys ++ [schedule_time: nil]

    @typedoc """
    Root of a component tree/scene that should be rendered for the output. [Learn more](https://compositor.live/docs/concept/component)
    """
    @type scene_root :: any()

    @type t :: %__MODULE__{
            output_id: LiveCompositor.output_id(),
            root: scene_root(),
            schedule_time: Membrane.Time | nil
          }
  end

  defimpl ApiClient.IntoRequest, for: UpdateVideoOutput do
    @spec into_request(UpdateVideoOutput.t()) :: ApiClient.request()
    def into_request(action) do
      body = %{
        video: %{
          root: action.root
        },
        schedule_time_ms:
          case action.schedule_time do
            nil -> nil
            offset -> Membrane.Time.as_milliseconds(offset, :round)
          end
      }

      encoded_id = URI.encode_www_form(action.output_id)
      {:post, "/api/output/#{encoded_id}/update", body}
    end
  end

  defmodule UpdateAudioOutput do
    @moduledoc """
    Action to update configuration of an audio output. You can define what inputs and volume should
    be used to produce the output.
    """

    alias Membrane.LiveCompositor

    @enforce_keys [:output_id, :inputs]
    defstruct @enforce_keys ++ [schedule_time: nil]

    @typedoc """
    - `input_id` - ID of an input that will be used to produce output.
    - `volume` - Number between 0 and 1 that represent volume of the input.
    """
    @type input :: %{input_id: LiveCompositor.input_id(), volume: float() | nil}

    @type t :: %__MODULE__{
            output_id: LiveCompositor.output_id(),
            inputs: list(input()),
            schedule_time: Membrane.Time | nil
          }
  end

  defimpl ApiClient.IntoRequest, for: UpdateAudioOutput do
    @spec into_request(UpdateAudioOutput.t()) :: ApiClient.request()
    def into_request(action) do
      body = %{
        audio: action.inputs,
        schedule_time_ms:
          case action.schedule_time do
            nil -> nil
            offset -> Membrane.Time.as_milliseconds(offset, :round)
          end
      }

      encoded_id = URI.encode_www_form(action.output_id)
      {:post, "/api/output/#{encoded_id}/update", body}
    end
  end
end
