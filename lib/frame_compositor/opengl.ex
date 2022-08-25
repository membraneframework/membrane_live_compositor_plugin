defmodule Membrane.VideoCompositor.OpenGL do
  @moduledoc """
  This module implements video composition in OpenGL.
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  @impl true
  def init(_caps) do
    {:ok, %{}}
  end

  @impl true
  def merge_frames(frames, internal_state) do
    merged_frames_binary = frames.first <> frames.second
    {{:ok, merged_frames_binary}, internal_state}
  end
end

defmodule Membrane.VideoCompositor.OpenGL.Cpp do
  @moduledoc """
  This module implements video composition in OpenGL with a C++ backend
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.OpenGL.Native.Cpp

  @impl true
  def init(caps) do
    Cpp.init(caps, caps)
  end

  @impl true
  def merge_frames(%{first: first_frame, second: second_frame}, internal_state) do
    {Cpp.join_frames(first_frame, second_frame, internal_state), internal_state}
  end
end

defmodule Membrane.VideoCompositor.OpenGL.Rust do
  @moduledoc """
  This module implements video composition in OpenGL with a Rust backend
  """

  @behaviour Membrane.VideoCompositor.FrameCompositor

  alias Membrane.VideoCompositor.OpenGL.Native.Rust

  @impl true
  def init(%Membrane.RawVideo{width: width, height: height, pixel_format: pixel_format}) do
    input_caps = %Rust.RawVideo{width: width, height: height, pixel_format: pixel_format}
    output_caps = %Rust.RawVideo{width: width, height: 2 * height, pixel_format: pixel_format}

    Rust.init(input_caps, input_caps, output_caps)
  end

  @impl true
  def merge_frames(%{first: first, second: second}, internal_state) do
    {Rust.join_frames(first, second, internal_state), internal_state}
  end
end
