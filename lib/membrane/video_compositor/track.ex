defmodule Membrane.VideoCompositor.Track do
  @moduledoc false

  alias Membrane.Buffer

  @type t :: %__MODULE__{
          buffers: Qex.t(Buffer.t()),
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

  @spec push_frame(__MODULE__.t(), Buffer.t()) :: __MODULE__.t()
  def push_frame(%__MODULE__{buffers: buffers} = track, frame) do
    %__MODULE__{track | buffers: Qex.push(buffers, frame)}
  end

  @spec pop_frame(__MODULE__.t()) :: __MODULE__.t()
  def pop_frame(%__MODULE__{buffers: buffers} = track) do
    {_old_frame, buffers} = Qex.pop!(buffers)
    %__MODULE__{track | buffers: buffers}
  end

  @spec first_frame(__MODULE__.t()) :: Buffer.t()
  def first_frame(%__MODULE__{buffers: buffers}) do
    %Buffer{payload: frame} = Qex.first!(buffers)
    frame
  end

  @spec has_frame?(__MODULE__.t()) :: boolean
  def has_frame?(%__MODULE__{buffers: buffers}) do
    not Enum.empty?(buffers)
  end
end
