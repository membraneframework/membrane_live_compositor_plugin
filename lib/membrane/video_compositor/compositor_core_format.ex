defmodule Membrane.VideoCompositor.CompositorCoreFormat do
  @moduledoc """
  Describes CoreVC input format.
  """

  alias Membrane.{Pad, RawVideo}

  @enforce_keys [:pad_formats]
  defstruct @enforce_keys

  @typedoc """
  Stream format of Queue - VC Core communication.
  Queue sends %{Pad.ref() => binary()} map in buffer
  payload and this format describes each frame resolution.
  """
  @type t :: %__MODULE__{
          pad_formats: %{Pad.ref() => RawVideo.t()}
        }

  @spec pads(t()) :: MapSet.t()
  def pads(%__MODULE__{pad_formats: pad_formats}) do
    pad_formats
    |> MapSet.new(fn {pad, _pad_format} -> pad end)
  end

  @spec validate(t(), MapSet.t()) :: :ok
  def validate(compositor_core_format = %__MODULE__{pad_formats: pad_formats}, input_pads) do
    format_pads = pad_formats |> Map.keys() |> MapSet.new()

    unless MapSet.equal?(format_pads, input_pads) do
      raise """
      CompositorCoreFormat should contain all input pads formats.
      CompositorCoreFormat: #{inspect(compositor_core_format)}
      Input pads: #{inspect(MapSet.to_list(input_pads))}
      """
    end

    :ok
  end
end
