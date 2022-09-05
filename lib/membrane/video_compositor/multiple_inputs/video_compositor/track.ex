defmodule Membrane.VideoCompositor.MultipleInputs.VideoCompositor.Track do
  @moduledoc false

  @type buffer_t :: Membrane.Buffer.t()

  @type t :: %__MODULE__{
          buffers: Qex.t(buffer_t),
          status: :playing | :end_of_stream
        }
  defstruct buffers: Qex.new(), status: :playing

  @doc """
  Checks whether track is empty and can be removed
  """
  @spec finished?(__MODULE__.t()) :: boolean()
  def finished?(%__MODULE__{status: status, buffers: buffers}) do
    status == :end_of_stream and Enum.empty?(buffers)
  end

  @spec push_frame(__MODULE__.t(), buffer_t) :: __MODULE__.t()
  def push_frame(%__MODULE__{buffers: buffers} = track, frame) do
    %__MODULE__{track | buffers: Qex.push(buffers, frame)}
  end

  @spec pop_frame(__MODULE__.t()) :: __MODULE__.t()
  def pop_frame(%__MODULE__{buffers: buffers} = track) do
    %__MODULE__{track | buffers: Qex.pop!(buffers) |> elem(1)}
  end

  @spec first_frame(__MODULE__.t()) :: buffer_t
  def first_frame(%__MODULE__{buffers: buffers}) do
    Qex.first!(buffers)
  end

  @spec has_frame?(__MODULE__.t()) :: boolean
  def has_frame?(%__MODULE__{buffers: buffers}) do
    not Enum.empty?(buffers)
  end
end
