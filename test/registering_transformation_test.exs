defmodule Membrane.VideoCompositor.RegisteringTransformationTest do
  use ExUnit.Case

  alias Membrane.VideoCompositor.{Wgpu.Native, WgpuAdapter}

  defmodule MockTransformation do
    @behaviour Membrane.VideoCompositor.Transformation

    @impl true
    def initialize(wgpu_ctx) do
      Native.mock_transformation(wgpu_ctx)
    end

    @impl true
    def encode(_transformation) do
      42
    end
  end

  test "initializes correctly with a mock transformation" do
    compositor = WgpuAdapter.init_new_compositor()
    assert :ok = WgpuAdapter.register_transformations(compositor, [MockTransformation])
  end
end
