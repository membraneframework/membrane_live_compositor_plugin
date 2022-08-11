defmodule VideoCompositor.OpenGL.Rust.Test do
  use ExUnit.Case, async: true

  alias Membrane.VideoCompositor.OpenGL.Rust

  test "inits" do
    first_video = %Rust.Raw

    assert {:ok, state} = Rust.init()
  end
end
