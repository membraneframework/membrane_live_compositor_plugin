defmodule Membrane.VideoCompositor.Implementation.OpenGL.Cpp do
  @moduledoc """
  This module implements video composition in OpenGL with a C++ backend
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.Implementation.OpenGL.Native.Cpp

  @impl true
  def init(caps) do
    Cpp.init(caps, caps)
  end

  @impl true
  def merge_frames(%{first: first_frame, second: second_frame}, internal_state) do
    {Cpp.join_frames(first_frame, second_frame, internal_state), internal_state}
  end
end
